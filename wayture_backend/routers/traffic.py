"""Traffic data endpoints.

POST /traffic              — upload one or many traffic records to Firestore
GET  /traffic              — fetch all stored traffic data
GET  /traffic/{location}   — fetch traffic for a specific location
POST /realtime-update      — receive a live traffic update
GET  /route                — Google Maps Directions with traffic info
POST /train-model          — train ML model on stored traffic data
GET  /predict              — ML-based congestion prediction
GET  /incidents            — fetch all active incidents
POST /incidents            — report a new incident
PUT  /incidents/{id}/resolve — mark incident as resolved
GET  /nepal-locations      — fetch pre-seeded Nepal locations
POST /seed-data            — populate Firestore with Nepal sample data
"""

import random
from datetime import datetime, timezone, timedelta

from fastapi import APIRouter, HTTPException, Query

from models.schemas import (
    TrafficDataUpload,
    TrafficDataResponse,
    TrafficBulkUpload,
    TrafficRealtimeUpdate,
    MLPredictionResponse,
    IncidentCreate,
    IncidentResponse,
    NepalLocation,
)
from services.firebase_service import firebase_service
from services.ml_service import ml_service

router = APIRouter()


# ── POST /upload-traffic — upload traffic data to Firestore ─────

@router.post("/traffic", response_model=dict)
async def upload_traffic(data: TrafficDataUpload):
    """Accept a single traffic observation and store it in Firestore."""
    if not firebase_service.is_initialized:
        raise HTTPException(status_code=503, detail="Firebase not initialized")

    record = data.model_dump()
    doc_id = await firebase_service.store_traffic_data(record)
    return {"status": "ok", "id": doc_id, "message": "Traffic data stored"}


@router.post("/traffic-bulk", response_model=dict)
async def upload_traffic_bulk(payload: TrafficBulkUpload):
    """Accept multiple traffic records at once (for Excel import)."""
    if not firebase_service.is_initialized:
        raise HTTPException(status_code=503, detail="Firebase not initialized")

    records = [r.model_dump() for r in payload.records]
    count = await firebase_service.store_traffic_batch(records)
    return {"status": "ok", "count": count, "message": f"{count} records stored"}


# ── GET /traffic — fetch all traffic data ───────────────────────

@router.get("/traffic", response_model=list[TrafficDataResponse])
async def get_all_traffic(limit: int = Query(default=500, ge=1, le=2000)):
    """Fetch all traffic data from Firestore, newest first."""
    if not firebase_service.is_initialized:
        raise HTTPException(status_code=503, detail="Firebase not initialized")

    docs = await firebase_service.get_all_traffic_data(limit=limit)
    return [_doc_to_response(d) for d in docs]


# ── GET /traffic/{location} — traffic for a specific location ──

@router.get("/traffic/{location}", response_model=list[TrafficDataResponse])
async def get_traffic_by_location(location: str):
    """Fetch traffic records for a named location (e.g. 'Koteshwor')."""
    if not firebase_service.is_initialized:
        raise HTTPException(status_code=503, detail="Firebase not initialized")

    docs = await firebase_service.get_traffic_by_location(location)
    if not docs:
        raise HTTPException(status_code=404, detail=f"No traffic data found for '{location}'")
    return [_doc_to_response(d) for d in docs]


# ── POST /realtime-update — live traffic observation ────────────

@router.post("/realtime-update", response_model=dict)
async def realtime_update(data: TrafficRealtimeUpdate):
    """Receive a live traffic update and store/overwrite in Firestore."""
    if not firebase_service.is_initialized:
        raise HTTPException(status_code=503, detail="Firebase not initialized")

    record = data.model_dump()
    doc_id = await firebase_service.store_realtime_update(record)
    return {"status": "ok", "id": doc_id, "message": "Real-time update stored"}


@router.get("/realtime", response_model=list[dict])
async def get_realtime_traffic():
    """Fetch all current real-time traffic snapshots."""
    if not firebase_service.is_initialized:
        raise HTTPException(status_code=503, detail="Firebase not initialized")

    return await firebase_service.get_all_realtime_traffic()


# ── GET /route moved to routers/maps.py (Google Maps + OSRM fallback) ──


# ── ML Endpoints ────────────────────────────────────────────────

@router.post("/train-model", response_model=dict)
async def train_model():
    """Train the ML model on all historical traffic data in Firestore."""
    if not firebase_service.is_initialized:
        raise HTTPException(status_code=503, detail="Firebase not initialized")
    if not ml_service.is_available:
        raise HTTPException(status_code=503, detail="scikit-learn not installed")

    records = await firebase_service.get_all_traffic_for_ml()
    if not records:
        raise HTTPException(status_code=404, detail="No traffic data in Firestore to train on")

    result = ml_service.train(records)
    if result["status"] != "ok":
        raise HTTPException(status_code=400, detail=result["message"])

    return result


@router.get("/predict", response_model=MLPredictionResponse)
async def predict_traffic(
    location: str = Query(..., description="Location name"),
    latitude: float = Query(default=27.7172, ge=-90, le=90),
    longitude: float = Query(default=85.3240, ge=-180, le=180),
    hour: int = Query(default=None, ge=0, le=23),
    day_of_week: str = Query(default=None, description="Day name e.g. Monday"),
):
    """Get ML-based traffic congestion prediction for a location and time."""
    result = ml_service.predict(
        location=location,
        latitude=latitude,
        longitude=longitude,
        hour=hour,
        day_of_week=day_of_week,
    )
    return MLPredictionResponse(**result)


# ── Helpers ─────────────────────────────────────────────────────

def _doc_to_response(doc: dict) -> TrafficDataResponse:
    """Convert a Firestore document dict to a TrafficDataResponse."""
    return TrafficDataResponse(
        id=doc.get("id", ""),
        location_name=doc.get("location_name", ""),
        latitude=doc.get("latitude", 0.0),
        longitude=doc.get("longitude", 0.0),
        congestion_level=doc.get("congestion_level", "low"),
        vehicle_count=doc.get("vehicle_count", 0),
        average_speed_kmh=doc.get("average_speed_kmh", 0.0),
        hour=doc.get("hour", 0),
        day_of_week=doc.get("day_of_week", ""),
        date=doc.get("date"),
        source=doc.get("source", "manual"),
        timestamp=doc.get("timestamp"),
    )


# ── Incidents ───────────────────────────────────────────────────

@router.get("/incidents", response_model=list[IncidentResponse])
async def get_incidents(active_only: bool = Query(default=True)):
    """Fetch incidents. By default returns only active ones."""
    if not firebase_service.is_initialized:
        raise HTTPException(status_code=503, detail="Firebase not initialized")

    if active_only:
        docs = await firebase_service.get_active_incidents()
    else:
        docs = await firebase_service.get_all_incidents()

    return [
        IncidentResponse(
            id=d.get("id", ""),
            incident_type=d.get("incident_type", ""),
            description=d.get("description", ""),
            latitude=d.get("latitude", 0.0),
            longitude=d.get("longitude", 0.0),
            location_name=d.get("location_name", ""),
            severity=d.get("severity", "medium"),
            reported_by=d.get("reported_by", "anonymous"),
            is_active=d.get("is_active", True),
            timestamp=d.get("timestamp"),
        )
        for d in docs
    ]


@router.post("/incidents", response_model=dict)
async def create_incident(data: IncidentCreate):
    """Report a new incident."""
    if not firebase_service.is_initialized:
        raise HTTPException(status_code=503, detail="Firebase not initialized")

    record = data.model_dump()
    doc_id = await firebase_service.create_incident(record)
    return {"status": "ok", "id": doc_id, "message": "Incident reported"}


@router.put("/incidents/{incident_id}/resolve", response_model=dict)
async def resolve_incident(incident_id: str):
    """Mark an incident as resolved (is_active=False)."""
    if not firebase_service.is_initialized:
        raise HTTPException(status_code=503, detail="Firebase not initialized")

    try:
        await firebase_service.resolve_incident(incident_id)
        return {"status": "ok", "message": f"Incident {incident_id} resolved"}
    except Exception as e:
        raise HTTPException(status_code=404, detail=f"Incident not found: {e}")


# ── Nepal Locations ─────────────────────────────────────────────

@router.get("/nepal-locations", response_model=list[NepalLocation])
async def get_nepal_locations():
    """Fetch all pre-seeded Nepal traffic hotspot locations."""
    if not firebase_service.is_initialized:
        raise HTTPException(status_code=503, detail="Firebase not initialized")

    docs = await firebase_service.get_nepal_locations()
    return [
        NepalLocation(
            id=d.get("id"),
            location_name=d.get("location_name", ""),
            district=d.get("district", ""),
            latitude=d.get("latitude", 0.0),
            longitude=d.get("longitude", 0.0),
            road_name=d.get("road_name", ""),
            is_hotspot=d.get("is_hotspot", True),
        )
        for d in docs
    ]


# ── Seed Data ───────────────────────────────────────────────────

# Nepal traffic hotspot locations
_NEPAL_LOCATIONS = [
    {"location_name": "Koteshwor", "district": "Kathmandu", "latitude": 27.6781, "longitude": 85.3499, "road_name": "Araniko Highway", "is_hotspot": True},
    {"location_name": "Kalanki", "district": "Kathmandu", "latitude": 27.6933, "longitude": 85.2814, "road_name": "Prithvi Highway", "is_hotspot": True},
    {"location_name": "Chabahil", "district": "Kathmandu", "latitude": 27.7178, "longitude": 85.3457, "road_name": "Ring Road", "is_hotspot": True},
    {"location_name": "Ratnapark", "district": "Kathmandu", "latitude": 27.7050, "longitude": 85.3150, "road_name": "Kantipath", "is_hotspot": True},
    {"location_name": "Maharajgunj", "district": "Kathmandu", "latitude": 27.7369, "longitude": 85.3300, "road_name": "Ring Road", "is_hotspot": True},
    {"location_name": "Pokhara Lakeside", "district": "Kaski", "latitude": 28.2096, "longitude": 83.9856, "road_name": "Lakeside Road", "is_hotspot": True},
    {"location_name": "Birgunj Border", "district": "Parsa", "latitude": 27.0104, "longitude": 84.8770, "road_name": "Mahendra Highway", "is_hotspot": True},
    {"location_name": "Banepa", "district": "Kavrepalanchok", "latitude": 27.6292, "longitude": 85.5227, "road_name": "Araniko Highway", "is_hotspot": True},
    {"location_name": "Thamel", "district": "Kathmandu", "latitude": 27.7153, "longitude": 85.3123, "road_name": "Thamel Marg", "is_hotspot": True},
    {"location_name": "New Baneshwor", "district": "Kathmandu", "latitude": 27.6882, "longitude": 85.3419, "road_name": "BP Highway", "is_hotspot": True},
    {"location_name": "Maitighar", "district": "Kathmandu", "latitude": 27.6947, "longitude": 85.3222, "road_name": "Singha Durbar Road", "is_hotspot": True},
    {"location_name": "Balaju", "district": "Kathmandu", "latitude": 27.7343, "longitude": 85.3042, "road_name": "Ring Road", "is_hotspot": True},
]

_DAYS = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
_CONGESTION_LEVELS = ["low", "medium", "high"]
_INCIDENT_TYPES = ["accident", "road_block", "flood", "construction"]
_SEVERITIES = ["low", "medium", "high"]


@router.post("/seed-data", response_model=dict)
async def seed_data():
    """Populate Firestore with realistic Nepal traffic sample data.

    Creates documents in: nepal_locations, traffic_data, traffic_realtime,
    incidents, route_suggestions.
    """
    if not firebase_service.is_initialized:
        raise HTTPException(status_code=503, detail="Firebase not initialized")

    counts = {}

    # 1. Seed nepal_locations (8+ locations)
    for loc in _NEPAL_LOCATIONS:
        await firebase_service.add_nepal_location(loc)
    counts["nepal_locations"] = len(_NEPAL_LOCATIONS)

    # 2. Seed traffic_data (20+ documents with varied hours/days)
    traffic_records = []
    for loc in _NEPAL_LOCATIONS:
        for _ in range(random.randint(2, 4)):
            hour = random.randint(6, 21)
            day = random.choice(_DAYS)
            is_peak = hour in range(7, 10) or hour in range(16, 19)
            is_weekend = day == "Saturday"

            if is_peak and not is_weekend:
                speed = random.uniform(5, 15)
                level = random.choice(["medium", "high"])
                vehicles = random.randint(80, 200)
            elif is_peak and is_weekend:
                speed = random.uniform(15, 25)
                level = random.choice(["low", "medium"])
                vehicles = random.randint(40, 100)
            else:
                speed = random.uniform(25, 50)
                level = "low"
                vehicles = random.randint(10, 60)

            traffic_records.append({
                "location_name": loc["location_name"],
                "latitude": loc["latitude"] + random.uniform(-0.002, 0.002),
                "longitude": loc["longitude"] + random.uniform(-0.002, 0.002),
                "congestion_level": level,
                "vehicle_count": vehicles,
                "average_speed_kmh": round(speed, 1),
                "hour": hour,
                "day_of_week": day,
                "road_name": loc["road_name"],
                "district": loc["district"],
                "date": (datetime.now(timezone.utc) - timedelta(days=random.randint(0, 7))).strftime("%Y-%m-%d"),
                "source": "seed_data",
            })

    count = await firebase_service.store_traffic_batch(traffic_records)
    counts["traffic_data"] = count

    # 3. Seed traffic_realtime (one per location — current state)
    for loc in _NEPAL_LOCATIONS[:8]:
        hour = datetime.now().hour
        is_peak = hour in range(7, 10) or hour in range(16, 19)
        speed = random.uniform(5, 15) if is_peak else random.uniform(20, 45)
        level = "high" if speed < 10 else ("medium" if speed < 20 else "low")

        await firebase_service.store_realtime_update({
            "location_name": loc["location_name"],
            "latitude": loc["latitude"],
            "longitude": loc["longitude"],
            "congestion_level": level,
            "vehicle_count": random.randint(20, 150),
            "average_speed_kmh": round(speed, 1),
        })
    counts["traffic_realtime"] = min(8, len(_NEPAL_LOCATIONS))

    # 4. Seed incidents (5-8 active incidents)
    incident_descriptions = {
        "accident": [
            "Two vehicles collided near the junction",
            "Motorcycle accident blocking lane",
            "Bus and truck collision — traffic diverted",
        ],
        "road_block": [
            "Construction work — road partially closed",
            "Political rally blocking main road",
            "Road maintenance in progress",
        ],
        "flood": [
            "Road flooded after heavy rain",
            "Waterlogging at underpass",
        ],
        "construction": [
            "Flyover construction — single lane open",
            "Bridge repair work — detour required",
            "New road expansion — expect delays",
        ],
    }

    incident_count = 0
    for loc in random.sample(_NEPAL_LOCATIONS[:8], min(6, len(_NEPAL_LOCATIONS))):
        itype = random.choice(_INCIDENT_TYPES)
        descs = incident_descriptions.get(itype, ["Incident reported"])
        await firebase_service.create_incident({
            "incident_type": itype,
            "description": random.choice(descs),
            "latitude": loc["latitude"],
            "longitude": loc["longitude"],
            "location_name": loc["location_name"],
            "severity": random.choice(_SEVERITIES),
            "reported_by": "seed_data",
        })
        incident_count += 1
    counts["incidents"] = incident_count

    # 5. Seed route_suggestions (popular routes)
    route_pairs = [
        ("Koteshwor", "Thamel"),
        ("Kalanki", "New Baneshwor"),
        ("Maharajgunj", "Ratnapark"),
        ("Chabahil", "Balaju"),
        ("Maitighar", "Koteshwor"),
    ]
    for origin, dest in route_pairs:
        await firebase_service.add_route_suggestion({
            "origin": origin,
            "destination": dest,
            "primary_route": {
                "road_names": [f"Ring Road via {origin}"],
                "distance_km": round(random.uniform(3, 10), 1),
                "estimated_minutes": random.randint(15, 45),
            },
            "alternative_routes": [
                {
                    "road_names": [f"Inner road via {dest}"],
                    "distance_km": round(random.uniform(4, 12), 1),
                    "estimated_minutes": random.randint(20, 55),
                }
            ],
            "estimated_time_minutes": random.randint(15, 45),
            "distance_km": round(random.uniform(3, 10), 1),
            "traffic_level": random.choice(["low", "medium", "high"]),
        })
    counts["route_suggestions"] = len(route_pairs)

    # 6. Seed app ratings (sample user ratings)
    sample_ratings = [
        {"uid": "seed_user_1", "stars": 5, "feedback": "Great app for navigating Kathmandu traffic!", "app_version": "1.0.0"},
        {"uid": "seed_user_2", "stars": 4, "feedback": "Very helpful, could use more locations", "app_version": "1.0.0"},
        {"uid": "seed_user_3", "stars": 5, "feedback": "Accurate congestion predictions", "app_version": "1.0.0"},
        {"uid": "seed_user_4", "stars": 3, "feedback": "Good concept, needs more data", "app_version": "1.0.0"},
        {"uid": "seed_user_5", "stars": 4, "feedback": "Useful for daily commute", "app_version": "1.0.0"},
    ]
    for rating in sample_ratings:
        uid = rating.pop("uid")
        await firebase_service.store_rating(uid, rating)
    counts["appRatings"] = len(sample_ratings)

    # 7. Train ML model on the seeded data
    ml_status = "skipped"
    if ml_service.is_available:
        try:
            all_data = await firebase_service.get_all_traffic_for_ml()
            result = ml_service.train(all_data)
            ml_status = f"trained on {result.get('samples_trained', 0)} samples"
        except Exception as e:
            ml_status = f"failed: {e}"

    return {
        "status": "ok",
        "message": "Firestore seeded with Nepal traffic data",
        "collections_populated": counts,
        "ml_model": ml_status,
    }


