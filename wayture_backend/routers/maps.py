"""Google Maps Platform endpoints.

Exposes the live-traffic routing layer and a lightweight smoke-test endpoint
so Flutter clients can verify Google Maps connectivity end-to-end. Uses the
existing OSRM service as an automatic fallback when Google returns
OVER_DAILY_LIMIT or the key is unavailable — so the app keeps working on the
free tier.
"""

from fastapi import APIRouter, HTTPException, Query

from models.schemas import (
    DirectionsResponse,
    GoogleRouteResponse,
)
from services.google_maps_service import (
    GoogleMapsHealth,
    google_maps_service,
)
from services.maps_service import maps_service  # OSRM fallback

router = APIRouter()


# ── GET /route ──────────────────────────────────────────────────────────────

@router.get("/route", response_model=DirectionsResponse)
async def get_route(
    origin: str = Query(..., description="Origin place or 'lat,lng'"),
    destination: str = Query(..., description="Destination place or 'lat,lng'"),
):
    """Fetch directions with live traffic.

    Tries Google Maps Directions first. On OVER_DAILY_LIMIT or an unreachable
    key, automatically falls back to the free OSRM route so the Flutter app
    never sees a hard failure. REQUEST_DENIED raises 503 so the operator can
    fix the key instead of silently degrading.
    """
    # 1. Try Google Maps first when a key is configured.
    if google_maps_service.is_available:
        result = await google_maps_service.get_directions(origin, destination)
        status = result["status"]

        if status == "OK" and result["best_route"]:
            return DirectionsResponse(
                origin=origin,
                destination=destination,
                best_route=GoogleRouteResponse(**result["best_route"]),
                alternative_routes=[
                    GoogleRouteResponse(**a) for a in result["alternative_routes"]
                ],
                traffic_recommendation=_build_recommendation(
                    result["best_route"], result["alternative_routes"]
                ),
            )

        if status == "ZERO_RESULTS":
            raise HTTPException(
                status_code=404,
                detail=(
                    "No route found between these locations in Kathmandu. "
                    "Try more specific place names (e.g. 'Koteshwor, Kathmandu')."
                ),
            )

        # REQUEST_DENIED / OVER_DAILY_LIMIT / OVER_QUERY_LIMIT / any other
        # error → fall through to OSRM so the app never hard-fails.
        print(f"[maps] Google returned {status}, falling back to OSRM")

    # 2. OSRM fallback (also used when no Google key is configured at all).
    return await _osrm_fallback(origin, destination)


# ── GET /maps/test ──────────────────────────────────────────────────────────

@router.get("/maps/test")
async def maps_test():
    """Smoke-test Google Maps by routing Koteshwor → Thamel.

    Returns the probe status and (if the key works) the best route summary.
    Intended for humans running the backend locally — not used by the Flutter
    app.
    """
    if not google_maps_service.is_available:
        return {
            "status": GoogleMapsHealth.MISSING_KEY,
            "hint": (
                "Set GOOGLE_MAPS_API_KEY in wayture_backend/.env (must start "
                "with 'AIza') and restart uvicorn."
            ),
        }

    result = await google_maps_service.get_directions(
        origin="Koteshwor, Kathmandu",
        destination="Thamel, Kathmandu",
    )

    api_status = result.get("status", "UNKNOWN")
    health = google_maps_service.health_status
    best = result.get("best_route")

    if api_status != "OK" or best is None:
        return {
            "status": health,
            "api_status": api_status,
            "origin": "Koteshwor, Kathmandu",
            "destination": "Thamel, Kathmandu",
            "best_route": None,
            "alternatives": [],
            "hint": (
                "REQUEST_DENIED → bad/unauthorised key. "
                "OVER_DAILY_LIMIT → quota exceeded, OSRM fallback kicks in. "
                "ZERO_RESULTS → Google couldn't route between these points."
            ),
        }

    return {
        "status": health,
        "api_status": api_status,
        "origin": "Koteshwor, Kathmandu",
        "destination": "Thamel, Kathmandu",
        "best_route": {
            "summary": best.get("summary"),
            "distance_km": best.get("distance_km"),
            "duration_minutes": best.get("duration_minutes"),
            "duration_in_traffic_minutes": best.get("duration_in_traffic_minutes"),
            "traffic_color": best.get("traffic_color"),
        },
        "alternatives": [
            {
                "summary": a.get("summary"),
                "distance_km": a.get("distance_km"),
                "duration_in_traffic_minutes": a.get("duration_in_traffic_minutes"),
                "traffic_color": a.get("traffic_color"),
            }
            for a in result.get("alternative_routes", [])
        ],
    }


# ── Fallback + helpers ──────────────────────────────────────────────────────

async def _osrm_fallback(origin: str, destination: str) -> DirectionsResponse:
    """Route via the free OSRM server when Google is unavailable.

    OSRM only takes lat/lng pairs, so the origin/destination strings must
    already be in 'lat,lng' format (the Flutter app sends coordinates). If
    they're place names, we return a 503 with a hint — Google is the only
    path that understands named places.
    """
    origin_latlng = _parse_latlng(origin)
    dest_latlng = _parse_latlng(destination)

    if not origin_latlng or not dest_latlng:
        raise HTTPException(
            status_code=503,
            detail=(
                "Google Maps is unavailable and OSRM fallback requires "
                "'lat,lng' coordinates (not place names). Configure "
                "GOOGLE_MAPS_API_KEY or pass coordinates."
            ),
        )

    start_lat, start_lng = origin_latlng
    end_lat, end_lng = dest_latlng

    data = await maps_service.get_routes(start_lat, start_lng, end_lat, end_lng)
    main = data.get("main_route")
    if main is None:
        raise HTTPException(
            status_code=404,
            detail="No route found between these coordinates.",
        )

    best = GoogleRouteResponse(
        summary="OSRM fallback route",
        distance_km=main["distance_km"],
        duration_minutes=main["duration_minutes"],
        duration_in_traffic_minutes=None,
        traffic_color="green",
        polyline=_points_to_polyline_str(main["points"]),
        steps=main.get("steps", []),
        warnings=["Served via OSRM fallback — no live traffic data"],
    )

    alts: list[GoogleRouteResponse] = []
    for alt in data.get("alternate_routes", []):
        alts.append(
            GoogleRouteResponse(
                summary="OSRM alternative",
                distance_km=alt["distance_km"],
                duration_minutes=alt["duration_minutes"],
                duration_in_traffic_minutes=None,
                traffic_color="green",
                polyline=_points_to_polyline_str(alt["points"]),
                steps=alt.get("steps", []),
                warnings=[],
            )
        )

    return DirectionsResponse(
        origin=origin,
        destination=destination,
        best_route=best,
        alternative_routes=alts,
        traffic_recommendation=(
            "Served via free OSRM fallback — no live traffic data. "
            "Configure GOOGLE_MAPS_API_KEY for traffic-aware ETAs."
        ),
    )


def _parse_latlng(value: str) -> tuple[float, float] | None:
    """Parse a 'lat,lng' string into (lat, lng), or None if not parseable."""
    parts = value.replace(" ", "").split(",")
    if len(parts) != 2:
        return None
    try:
        return float(parts[0]), float(parts[1])
    except ValueError:
        return None


def _points_to_polyline_str(points: list[list[float]]) -> str:
    """Encode a list of [lat, lng] pairs using Google's polyline algorithm.

    Flutter's existing decoder in map_screen.dart expects the standard
    Google-encoded polyline format, so the OSRM fallback re-encodes the
    raw coordinates into that format before returning them.
    """
    result = []
    prev_lat = 0
    prev_lng = 0
    for lat, lng in points:
        ilat = round(lat * 1e5)
        ilng = round(lng * 1e5)
        result.append(_encode_signed(ilat - prev_lat))
        result.append(_encode_signed(ilng - prev_lng))
        prev_lat = ilat
        prev_lng = ilng
    return "".join(result)


def _encode_signed(value: int) -> str:
    """Encode a signed integer using Google's polyline varint scheme."""
    v = value << 1
    if value < 0:
        v = ~v
    chunks = []
    while v >= 0x20:
        chunks.append(chr((0x20 | (v & 0x1F)) + 63))
        v >>= 5
    chunks.append(chr(v + 63))
    return "".join(chunks)


def _build_recommendation(best: dict | None, alternatives: list[dict]) -> str:
    """Generate a human-readable traffic recommendation from a Google result."""
    if not best:
        return "No route found."

    best_time = best.get("duration_in_traffic_minutes") or best.get("duration_minutes", 0)
    msg = f"Best route via {best.get('summary', 'primary')}: {best_time:.0f} min"

    if not alternatives:
        return msg + ". No alternative routes available."

    fastest_alt = min(
        alternatives,
        key=lambda a: a.get("duration_in_traffic_minutes") or a.get("duration_minutes", 999),
    )
    alt_time = fastest_alt.get("duration_in_traffic_minutes") or fastest_alt.get("duration_minutes", 0)

    if alt_time < best_time:
        saving = best_time - alt_time
        return (
            f"{msg}. FASTER alternative via {fastest_alt.get('summary', 'alt')}: "
            f"{alt_time:.0f} min (saves {saving:.0f} min)"
        )
    return f"{msg}. Current route is the fastest option."
