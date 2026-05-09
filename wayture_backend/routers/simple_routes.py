"""Simple Find Routes endpoint used by the demo screen.

Flow (all free, no keys required):
  1. Geocode the origin + destination text via Nominatim (OpenStreetMap).
  2. Ask OSRM for up to 3 driving routes between those two points.
  3. Classify each route as low / medium / high congestion using the ML
     model (or heuristic fallback).
  4. Return a flat JSON payload that Flutter can draw straight onto the map.

The goal is that the Flutter app can call a single URL and get everything
it needs to show three colored polylines with labels and ETAs.
"""

from datetime import datetime
from typing import Any

from fastapi import APIRouter, HTTPException, Query

from services.maps_service import maps_service
from services.traffic_predictor import traffic_predictor


router = APIRouter()


# ── GET /find-routes ───────────────────────────────────────────────────────

@router.get("/find-routes")
async def find_routes(
    origin: str = Query(..., description="Origin place name, e.g. 'Koteshwor'"),
    destination: str = Query(..., description="Destination place name, e.g. 'Thamel'"),
) -> dict[str, Any]:
    """Return up to 3 colored driving routes between two places.

    Response shape (matches lib/models/simple_route.dart):
        {
          "origin":      {"name": str, "lat": float, "lng": float},
          "destination": {"name": str, "lat": float, "lng": float},
          "routes": [
            {
              "index": int,             # 0, 1, 2
              "label": str,              # "Fastest", "Alternative 1", ...
              "distance_km": float,
              "duration_minutes": float,
              "congestion": "low" | "medium" | "high",
              "color_hex": "#RRGGBB",
              "points": [[lat, lng], ...]  # ready for flutter_map Polyline
            },
            ...
          ]
        }
    """
    # 1. Geocode both endpoints. Nominatim is biased toward Kathmandu in
    #    maps_service, so "Koteshwor" / "Thamel" resolve without extra help.
    origin_hits = await maps_service.geocode_place(origin, limit=1)
    if not origin_hits:
        raise HTTPException(
            status_code=404,
            detail=f"Could not find a location named '{origin}'. Try adding 'Kathmandu'.",
        )

    dest_hits = await maps_service.geocode_place(destination, limit=1)
    if not dest_hits:
        raise HTTPException(
            status_code=404,
            detail=f"Could not find a location named '{destination}'. Try adding 'Kathmandu'.",
        )

    origin_pt = origin_hits[0]
    dest_pt = dest_hits[0]

    # 2. Ask OSRM for main + up to 2 alternative routes.
    osrm = await maps_service.get_routes(
        start_lat=origin_pt["latitude"],
        start_lng=origin_pt["longitude"],
        end_lat=dest_pt["latitude"],
        end_lng=dest_pt["longitude"],
    )

    # Flatten into a single list: [main, alt1, alt2]
    raw_routes = []
    if osrm.get("main_route"):
        raw_routes.append(osrm["main_route"])
    raw_routes.extend(osrm.get("alternate_routes") or [])
    raw_routes = raw_routes[:3]  # hard cap at 3

    if not raw_routes:
        raise HTTPException(
            status_code=502,
            detail="Routing service returned no routes. Try again in a moment.",
        )

    # 3. Classify each route + attach a display color.
    hour_of_day = datetime.now().hour
    friendly_labels = ["Fastest route", "Alternative route 1", "Alternative route 2"]

    shaped_routes = []
    for i, route in enumerate(raw_routes):
        congestion = traffic_predictor.classify(
            distance_km=route["distance_km"],
            duration_minutes=route["duration_minutes"],
            hour_of_day=hour_of_day,
        )
        shaped_routes.append({
            "index": i,
            "label": friendly_labels[i] if i < len(friendly_labels) else f"Route {i + 1}",
            "distance_km": route["distance_km"],
            "duration_minutes": route["duration_minutes"],
            "congestion": congestion,
            "color_hex": traffic_predictor.color_for(congestion),
            "points": route["points"],
        })

    # 4. Shape the final JSON envelope.
    return {
        "origin": {
            "name": origin_pt.get("name") or origin,
            "lat": origin_pt["latitude"],
            "lng": origin_pt["longitude"],
        },
        "destination": {
            "name": dest_pt.get("name") or destination,
            "lat": dest_pt["latitude"],
            "lng": dest_pt["longitude"],
        },
        "routes": shaped_routes,
        "model_loaded": traffic_predictor.is_trained,
    }
