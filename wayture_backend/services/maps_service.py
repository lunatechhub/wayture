from typing import Optional

import httpx

# All services are completely FREE — no API keys needed

# OSRM public demo server (free, no key)
OSRM_BASE_URL = "http://router.project-osrm.org/route/v1/driving"

# Nominatim (free, no key — requires User-Agent)
NOMINATIM_BASE_URL = "https://nominatim.openstreetmap.org"

USER_AGENT = "Wayture/1.0 (traffic-congestion-predictor-kathmandu)"


class MapsService:

    async def get_routes(
        self,
        start_lat: float,
        start_lng: float,
        end_lat: float,
        end_lng: float,
    ) -> dict:
        """Fetch main route + up to 2 alternates from OSRM (free, no key).

        OSRM coordinate order: longitude,latitude
        Returns: {main_route: {...}, alternate_routes: [{...}, ...]}
        """
        url = (
            f"{OSRM_BASE_URL}/{start_lng},{start_lat};{end_lng},{end_lat}"
            f"?overview=full&geometries=geojson&alternatives=true&steps=true"
        )
        try:
            async with httpx.AsyncClient() as client:
                resp = await client.get(
                    url,
                    headers={"User-Agent": USER_AGENT},
                    timeout=10,
                )
                data = resp.json()

            if data.get("code") != "Ok" or not data.get("routes"):
                return {"main_route": None, "alternate_routes": []}

            routes = []
            for i, route in enumerate(data["routes"]):
                coordinates = route["geometry"]["coordinates"]
                # OSRM returns [lng, lat] — convert to [lat, lng] for Flutter
                points = [[coord[1], coord[0]] for coord in coordinates]

                routes.append({
                    "route_index": i,
                    "distance_km": round(route["distance"] / 1000, 2),
                    "duration_minutes": round(route["duration"] / 60, 1),
                    "points": points,
                    "steps": [
                        {
                            "instruction": step.get("maneuver", {}).get("type", ""),
                            "name": step.get("name", ""),
                            "distance_m": round(step.get("distance", 0)),
                            "duration_s": round(step.get("duration", 0)),
                        }
                        for leg in route.get("legs", [])
                        for step in leg.get("steps", [])
                    ],
                })

            return {
                "main_route": routes[0] if routes else None,
                "alternate_routes": routes[1:3],  # max 2 alternates
            }

        except Exception as e:
            print(f"[OSRM] Route fetch failed: {e}")
            return {"main_route": None, "alternate_routes": []}

    async def geocode_place(self, place_name: str, limit: int = 5) -> list[dict]:
        """Search for a place using Nominatim (free, no key).

        Biased toward Kathmandu results.
        """
        params = {
            "q": place_name,
            "format": "json",
            "limit": limit,
            "viewbox": "85.27,27.67,85.38,27.75",  # Kathmandu Metropolitan City only
            "bounded": 1,
            "addressdetails": 1,
        }
        try:
            async with httpx.AsyncClient() as client:
                resp = await client.get(
                    f"{NOMINATIM_BASE_URL}/search",
                    params=params,
                    headers={"User-Agent": USER_AGENT},
                    timeout=10,
                )
                data = resp.json()

            return [
                {
                    "name": item.get("display_name", ""),
                    "latitude": float(item["lat"]),
                    "longitude": float(item["lon"]),
                    "type": item.get("type", ""),
                }
                for item in data
            ]

        except Exception as e:
            print(f"[Nominatim] Geocode failed: {e}")
            return []

    async def reverse_geocode(self, lat: float, lng: float) -> Optional[str]:
        """Get address from coordinates using Nominatim (free, no key)."""
        params = {
            "lat": lat,
            "lon": lng,
            "format": "json",
        }
        try:
            async with httpx.AsyncClient() as client:
                resp = await client.get(
                    f"{NOMINATIM_BASE_URL}/reverse",
                    params=params,
                    headers={"User-Agent": USER_AGENT},
                    timeout=10,
                )
                data = resp.json()

            return data.get("display_name")

        except Exception:
            return None


maps_service = MapsService()
