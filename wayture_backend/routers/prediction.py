from datetime import datetime, timezone, timedelta

from fastapi import APIRouter, Depends

from models.schemas import (
    CongestionLevel,
    CongestionPredictionRequest,
    CongestionPredictionResponse,
    RouteInfo,
    TrafficStatusResponse,
)
from routers.auth import get_current_uid
from services.firebase_service import firebase_service
from services.groq_service import groq_service
from services.maps_service import maps_service
from services.weather_service import weather_service

router = APIRouter()

# --- Rule-Based Thresholds (Kathmandu) ---
SPEED_STOPPED = 2.0      # km/h — GPS stop = blockage
SPEED_SLOW = 10.0        # km/h — congestion
SPEED_MODERATE = 25.0    # km/h — moderate flow
REPORT_TIME_WINDOW = timedelta(minutes=10)
REPORT_CLUSTER_THRESHOLD = 3  # 3+ reports in same area within 10 min = HIGH


def _compute_score(
    user_speed: float | None,
    avg_nearby_speed: float | None,
    recent_reports_count: int,
    stopped_count: int,
    weather_factor: float,
) -> float:
    """Rule-based congestion score (0-100)."""
    score = 0.0

    # Rule 1: User's own speed
    if user_speed is not None:
        if user_speed <= SPEED_STOPPED:
            score += 35  # GPS stop = blockage
        elif user_speed <= SPEED_SLOW:
            score += 25
        elif user_speed <= SPEED_MODERATE:
            score += 10

    # Rule 2: Average nearby speed
    if avg_nearby_speed is not None:
        if avg_nearby_speed <= SPEED_STOPPED:
            score += 15
        elif avg_nearby_speed <= SPEED_SLOW:
            score += 10

    # Rule 3: Community reports (3+ in 10 min = HIGH)
    if recent_reports_count >= REPORT_CLUSTER_THRESHOLD:
        score += 30
    else:
        score += min(recent_reports_count * 8, 24)

    # Rule 4: Stopped vehicles nearby
    score += min(stopped_count * 5, 15)

    # Weather multiplier
    score *= weather_factor

    return min(max(score, 0), 100)


def _score_to_level(score: float) -> CongestionLevel:
    if score >= 60:
        return CongestionLevel.RED
    if score >= 30:
        return CongestionLevel.YELLOW
    return CongestionLevel.GREEN


def _level_to_color(level: CongestionLevel) -> str:
    return {"green": "#4CAF50", "yellow": "#FFC107", "red": "#F44336"}[level.value]


def _build_reason(
    user_speed: float | None,
    recent_reports_count: int,
    stopped_count: int,
    weather_label: str,
    level: CongestionLevel,
) -> str:
    """Human-readable reason for the congestion level."""
    reasons = []

    if user_speed is not None and user_speed <= SPEED_STOPPED:
        reasons.append("GPS stop detected (possible blockage)")
    elif user_speed is not None and user_speed <= SPEED_SLOW:
        reasons.append(f"Slow speed detected ({user_speed:.0f} km/h)")

    if recent_reports_count >= REPORT_CLUSTER_THRESHOLD:
        reasons.append(f"{recent_reports_count} reports in this area within 10 min")
    elif recent_reports_count > 0:
        reasons.append(f"{recent_reports_count} incident(s) reported nearby")

    if stopped_count > 0:
        reasons.append(f"{stopped_count} stopped vehicle(s) nearby")

    if weather_label != "clear":
        reasons.append(f"Weather: {weather_label.replace('_', ' ')}")

    if not reasons:
        if level == CongestionLevel.GREEN:
            return "Traffic is flowing smoothly"
        return "Moderate traffic detected"

    return "; ".join(reasons)


@router.post("/predict-congestion", response_model=CongestionPredictionResponse)
async def predict_congestion(
    req: CongestionPredictionRequest,
    uid: str = Depends(get_current_uid),
):
    """Full congestion prediction: rule-based score + OSRM routes + Open-Meteo weather."""

    # 1. Fetch routes from OSRM (free, no key)
    route_data = await maps_service.get_routes(
        req.user_lat, req.user_lng, req.dest_lat, req.dest_lng
    )

    # 2. Get weather from Open-Meteo (free, no key)
    weather = await weather_service.get_weather(req.user_lat, req.user_lng)
    weather_factor, weather_label = weather_service.get_congestion_factor(weather)

    is_raining = weather.get("is_raining", False) if weather else False
    temperature = weather.get("temperature") if weather else None
    weather_warning = None
    if is_raining:
        desc = weather.get("weather_description", "Rain") if weather else "Rain"
        weather_warning = f"{desc} detected — safer route recommended"

    # 3. Check Firebase for nearby community reports (last 10 min)
    recent_reports_count = 0
    stopped_count = 0
    avg_nearby_speed = None

    if firebase_service.is_initialized:
        try:
            nearby_reports = await firebase_service.get_nearby_reports(
                req.user_lat, req.user_lng, radius_km=1.0
            )
            cutoff = datetime.now(timezone.utc) - REPORT_TIME_WINDOW
            recent_reports_count = sum(
                1 for r in nearby_reports
                if r.get("created_at") and r["created_at"] >= cutoff
            )

            # Check nearby GPS locations for speed data
            nearby_locations = await firebase_service.get_nearby_locations(
                req.user_lat, req.user_lng, radius_km=1.0
            )
            speeds = [loc["speed"] for loc in nearby_locations if loc.get("speed") is not None]
            avg_nearby_speed = sum(speeds) / len(speeds) if speeds else None
            stopped_count = sum(
                1 for loc in nearby_locations
                if loc.get("speed", 999) <= SPEED_STOPPED
            )
        except Exception as e:
            print(f"[Prediction] Firebase query failed: {e}")

    # 4. Compute congestion score
    score = _compute_score(
        req.user_speed, avg_nearby_speed, recent_reports_count,
        stopped_count, weather_factor,
    )
    level = _score_to_level(score)
    reason = _build_reason(
        req.user_speed, recent_reports_count, stopped_count, weather_label, level,
    )

    # 5. Attach congestion level to each route
    main_route = None
    if route_data["main_route"]:
        r = route_data["main_route"]
        main_route = RouteInfo(
            route_index=0,
            distance_km=r["distance_km"],
            duration_minutes=r["duration_minutes"],
            points=r["points"],
            congestion_level=level,
            steps=r.get("steps", []),
        )

    alternate_routes = []
    main_duration = route_data["main_route"]["duration_minutes"] if route_data["main_route"] else None
    for i, alt in enumerate(route_data.get("alternate_routes", [])):
        # Score alternates based on duration comparison with main route
        # Shorter/similar duration = likely less congested
        alt_duration = alt["duration_minutes"]
        if main_duration and main_duration > 0:
            ratio = alt_duration / main_duration
            if ratio <= 0.85:
                alt_level = CongestionLevel.GREEN
            elif ratio <= 1.0:
                # Slightly shorter or same — one level better than main
                alt_level = CongestionLevel.GREEN if level != CongestionLevel.RED else CongestionLevel.YELLOW
            elif ratio <= 1.15:
                alt_level = level  # Similar to main
            else:
                # Longer route — likely same or worse congestion
                alt_level = CongestionLevel.YELLOW if level == CongestionLevel.GREEN else level
        else:
            alt_level = CongestionLevel.GREEN

        alternate_routes.append(RouteInfo(
            route_index=i + 1,
            distance_km=alt["distance_km"],
            duration_minutes=alt["duration_minutes"],
            points=alt["points"],
            congestion_level=alt_level,
            steps=alt.get("steps", []),
        ))

    # 6. Get AI insight + route suggestion from Groq
    ai_insight = None
    ai_route_suggestion = None
    if groq_service.is_available:
        try:
            # Build route dicts for Groq comparison
            main_route_data = None
            if main_route:
                main_route_data = {
                    "distance_km": main_route.distance_km,
                    "duration_minutes": main_route.duration_minutes,
                    "congestion_level": main_route.congestion_level.value,
                }
            alt_route_data = [
                {
                    "distance_km": alt.distance_km,
                    "duration_minutes": alt.duration_minutes,
                    "congestion_level": alt.congestion_level.value,
                }
                for alt in alternate_routes
            ]

            groq_result = await groq_service.get_traffic_insight(
                congestion_level=level.value,
                congestion_reason=reason,
                score=score,
                weather_label=weather_label,
                reports_count=recent_reports_count,
                distance_km=main_route.distance_km if main_route else None,
                duration_min=main_route.duration_minutes if main_route else None,
                is_raining=is_raining,
                main_route=main_route_data,
                alternate_routes=alt_route_data,
            )
            ai_insight = groq_result.get("insight")
            ai_route_suggestion = groq_result.get("route_suggestion")
        except Exception as e:
            print(f"[Prediction] Groq insight failed: {e}")

    return CongestionPredictionResponse(
        congestion_level=level,
        congestion_reason=reason,
        main_route=main_route,
        alternate_routes=alternate_routes,
        weather_warning=weather_warning,
        estimated_time_minutes=main_route.duration_minutes if main_route else None,
        nearby_reports_count=recent_reports_count,
        is_raining=is_raining,
        temperature=temperature,
        ai_insight=ai_insight,
        ai_route_suggestion=ai_route_suggestion,
    )


@router.get("/traffic-status/{lat}/{lng}", response_model=TrafficStatusResponse)
async def get_traffic_status(lat: float, lng: float, uid: str = Depends(get_current_uid)):
    """Get colour-coded traffic status for map display at a specific point."""

    # Weather
    weather = await weather_service.get_weather(lat, lng)
    weather_factor, weather_label = weather_service.get_congestion_factor(weather)

    # Firebase data
    recent_reports_count = 0
    stopped_count = 0
    avg_speed = None

    if firebase_service.is_initialized:
        try:
            nearby_reports = await firebase_service.get_nearby_reports(lat, lng, radius_km=0.5)
            cutoff = datetime.now(timezone.utc) - REPORT_TIME_WINDOW
            recent_reports_count = sum(
                1 for r in nearby_reports
                if r.get("created_at") and r["created_at"] >= cutoff
            )

            nearby_locations = await firebase_service.get_nearby_locations(lat, lng, radius_km=0.5)
            speeds = [loc["speed"] for loc in nearby_locations if loc.get("speed") is not None]
            avg_speed = sum(speeds) / len(speeds) if speeds else None
            stopped_count = sum(
                1 for loc in nearby_locations
                if loc.get("speed", 999) <= SPEED_STOPPED
            )
        except Exception as e:
            print(f"[TrafficStatus] Firebase query failed: {e}")

    score = _compute_score(None, avg_speed, recent_reports_count, stopped_count, weather_factor)
    level = _score_to_level(score)

    messages = {
        CongestionLevel.GREEN: "Traffic is flowing smoothly",
        CongestionLevel.YELLOW: "Moderate congestion — allow extra time",
        CongestionLevel.RED: "Heavy congestion — consider alternate routes",
    }

    return TrafficStatusResponse(
        congestion_level=level,
        color=_level_to_color(level),
        score=round(score, 1),
        avg_speed_kmh=round(avg_speed, 1) if avg_speed else None,
        nearby_reports_count=recent_reports_count,
        stopped_vehicles_count=stopped_count,
        weather_factor=weather_label,
        message=messages[level],
    )
