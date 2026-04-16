"""Google Maps Platform service.

Wraps the Google Maps HTTP APIs we use from the backend:

    • Directions          (live-traffic-aware routing)
    • Distance Matrix     (ETA between origin/destination pairs)
    • Geocoding           (address → lat/lng)
    • Reverse geocoding   (lat/lng → address)
    • Places Autocomplete (typeahead bounded to Kathmandu)

The existing free-tier services (OSRM, Nominatim, Open-Meteo, OpenStreetMap
tiles) remain the fallback path when this service isn't available or returns
OVER_DAILY_LIMIT — callers should use [is_available] + the [status] field on
each result to decide when to fall back.
"""

import os
from typing import Optional

import httpx
from dotenv import load_dotenv

load_dotenv()

# ── API endpoints ────────────────────────────────────────────────────────────
DIRECTIONS_URL = "https://maps.googleapis.com/maps/api/directions/json"
DISTANCE_MATRIX_URL = "https://maps.googleapis.com/maps/api/distancematrix/json"
GEOCODE_URL = "https://maps.googleapis.com/maps/api/geocode/json"
PLACES_AUTOCOMPLETE_URL = "https://maps.googleapis.com/maps/api/place/autocomplete/json"

# Kathmandu centre — used as a bias for autocomplete results.
KATHMANDU_LAT = 27.7172
KATHMANDU_LNG = 85.3240
KATHMANDU_RADIUS_METERS = 20000  # ~20 km around the valley


# ── Health states exposed through the /health endpoint ──────────────────────
class GoogleMapsHealth:
    MISSING_KEY = "missing api key"
    CONNECTED = "connected"
    INVALID_KEY = "invalid api key"
    QUOTA_EXCEEDED = "quota exceeded"
    UNREACHABLE = "unreachable"


class GoogleMapsService:
    """Wrapper around Google Maps Platform HTTP APIs."""

    # Sentinel placeholders we treat as "unconfigured".
    _PLACEHOLDERS = {
        "",
        "GOOGLE_MAPS_API_KEY_HERE",
        "your_google_maps_api_key_here",
    }

    def __init__(self):
        self._api_key = os.getenv("GOOGLE_MAPS_API_KEY", "").strip()
        self._health_status: str = (
            GoogleMapsHealth.MISSING_KEY
            if self._is_placeholder(self._api_key)
            else GoogleMapsHealth.CONNECTED
        )

    # ── Key / health helpers ─────────────────────────────────────

    def _is_placeholder(self, value: str) -> bool:
        return value in self._PLACEHOLDERS

    @property
    def is_available(self) -> bool:
        """True when a non-placeholder key is configured.

        Note: this does NOT guarantee the key works. Use [probe_connection]
        once at startup to verify, and check [health_status] thereafter.
        """
        return not self._is_placeholder(self._api_key)

    @property
    def health_status(self) -> str:
        """Current Google Maps health — one of [GoogleMapsHealth] constants."""
        return self._health_status

    async def probe_connection(self) -> str:
        """Do one cheap live call to verify the key works.

        Called from the FastAPI lifespan. Caches the result in
        [health_status] so the /health endpoint can return it without
        spending quota on every request.
        """
        if not self.is_available:
            self._health_status = GoogleMapsHealth.MISSING_KEY
            return self._health_status

        # Geocode a fixed Kathmandu landmark — cheapest possible call.
        params = {
            "address": "Ratnapark, Kathmandu",
            "key": self._api_key,
            "region": "np",
        }
        try:
            async with httpx.AsyncClient() as client:
                resp = await client.get(GEOCODE_URL, params=params, timeout=5)
                data = resp.json()
        except Exception as e:
            print(f"[GoogleMaps] Probe unreachable: {e}")
            self._health_status = GoogleMapsHealth.UNREACHABLE
            return self._health_status

        status = data.get("status", "")
        self._health_status = self._map_status_to_health(status)
        return self._health_status

    @staticmethod
    def _map_status_to_health(status: str) -> str:
        """Map a Google Maps API response status to our health enum."""
        if status == "OK" or status == "ZERO_RESULTS":
            # ZERO_RESULTS still means the key is valid.
            return GoogleMapsHealth.CONNECTED
        if status == "REQUEST_DENIED":
            print("[GoogleMaps] REQUEST_DENIED — Invalid API Key")
            return GoogleMapsHealth.INVALID_KEY
        if status == "OVER_DAILY_LIMIT" or status == "OVER_QUERY_LIMIT":
            print(f"[GoogleMaps] {status} — quota exceeded, fall back to OSRM")
            return GoogleMapsHealth.QUOTA_EXCEEDED
        print(f"[GoogleMaps] Unexpected probe status: {status}")
        return GoogleMapsHealth.UNREACHABLE

    # ── Directions API ──────────────────────────────────────────

    async def get_directions(
        self,
        origin: str,
        destination: str,
        alternatives: bool = True,
    ) -> dict:
        """Fetch directions from Google Maps with traffic info.

        Returns:
            {
                "best_route": {...} | None,
                "alternative_routes": [{...}, ...],   # up to 2 more (3 total)
                "status": "OK" | "ZERO_RESULTS" | "REQUEST_DENIED" | ...,
            }

        Each route dict contains distance_km, duration_minutes,
        duration_in_traffic_minutes, polyline, steps, warnings, and a
        `traffic_color` ("green" / "yellow" / "red") derived from the ratio
        of traffic duration to free-flow duration.
        """
        if not self.is_available:
            return {
                "best_route": None,
                "alternative_routes": [],
                "status": "NO_API_KEY",
            }

        params = {
            "origin": origin,
            "destination": destination,
            "key": self._api_key,
            "alternatives": str(alternatives).lower(),
            "departure_time": "now",          # enables duration_in_traffic
            "traffic_model": "best_guess",    # best_guess / pessimistic / optimistic
            "region": "np",                   # bias results to Nepal
        }

        try:
            async with httpx.AsyncClient() as client:
                resp = await client.get(DIRECTIONS_URL, params=params, timeout=15)
                data = resp.json()
        except Exception as e:
            print(f"[GoogleMaps] Directions error: {e}")
            return {
                "best_route": None,
                "alternative_routes": [],
                "status": f"ERROR: {e}",
            }

        status = data.get("status", "UNKNOWN")

        # Keep cached health status fresh on every hot call.
        self._health_status = self._map_status_to_health(status)

        if status != "OK" or not data.get("routes"):
            return {
                "best_route": None,
                "alternative_routes": [],
                "status": status,
            }

        routes: list[dict] = []
        for route in data["routes"][:3]:  # cap at 3 alternatives
            leg = route["legs"][0]

            distance_m = leg["distance"]["value"]
            duration_s = leg["duration"]["value"]
            traffic_s = leg.get("duration_in_traffic", {}).get("value")

            steps = [
                {
                    "instruction": step.get("html_instructions", ""),
                    "distance_m": step["distance"]["value"],
                    "duration_s": step["duration"]["value"],
                    "travel_mode": step.get("travel_mode", "DRIVING"),
                }
                for step in leg.get("steps", [])
            ]

            duration_min = round(duration_s / 60, 1)
            traffic_min = round(traffic_s / 60, 1) if traffic_s else None

            routes.append({
                "summary": route.get("summary", ""),
                "distance_km": round(distance_m / 1000, 2),
                "duration_minutes": duration_min,
                "duration_in_traffic_minutes": traffic_min,
                "traffic_color": self.traffic_severity_color(duration_min, traffic_min),
                "polyline": route.get("overview_polyline", {}).get("points", ""),
                "steps": steps,
                "warnings": route.get("warnings", []),
            })

        return {
            "best_route": routes[0] if routes else None,
            "alternative_routes": routes[1:],
            "status": "OK",
        }

    @staticmethod
    def traffic_severity_color(
        duration_minutes: float,
        duration_in_traffic_minutes: Optional[float],
    ) -> str:
        """Map the traffic/free-flow ratio to a severity color.

        • green  — ratio ≤ 1.10 (minimal traffic)
        • yellow — ratio ≤ 1.30 (moderate)
        • red    — ratio >  1.30 (heavy)

        Returns "green" when traffic duration is missing (free-flow fallback).
        """
        if not duration_in_traffic_minutes or duration_minutes <= 0:
            return "green"
        ratio = duration_in_traffic_minutes / duration_minutes
        if ratio <= 1.10:
            return "green"
        if ratio <= 1.30:
            return "yellow"
        return "red"

    # ── Distance Matrix API ─────────────────────────────────────

    async def get_distance_matrix(
        self,
        origins: list[str],
        destinations: list[str],
    ) -> Optional[dict]:
        """Fetch distance + duration between multiple origin/destination pairs."""
        if not self.is_available:
            return None

        params = {
            "origins": "|".join(origins),
            "destinations": "|".join(destinations),
            "key": self._api_key,
            "departure_time": "now",
            "traffic_model": "best_guess",
            "region": "np",
        }

        try:
            async with httpx.AsyncClient() as client:
                resp = await client.get(DISTANCE_MATRIX_URL, params=params, timeout=15)
                data = resp.json()
        except Exception as e:
            print(f"[GoogleMaps] Distance matrix error: {e}")
            return None

        status = data.get("status", "")
        self._health_status = self._map_status_to_health(status)

        if status != "OK":
            return None

        results = []
        for row in data.get("rows", []):
            row_results = []
            for element in row.get("elements", []):
                if element.get("status") != "OK":
                    row_results.append(None)
                    continue
                row_results.append({
                    "distance_km": round(element["distance"]["value"] / 1000, 2),
                    "duration_minutes": round(element["duration"]["value"] / 60, 1),
                    "duration_in_traffic_minutes": round(
                        element.get("duration_in_traffic", {}).get("value", 0) / 60, 1
                    ) if element.get("duration_in_traffic") else None,
                })
            results.append(row_results)

        return {
            "origin_addresses": data.get("origin_addresses", []),
            "destination_addresses": data.get("destination_addresses", []),
            "rows": results,
        }

    # ── Geocoding ───────────────────────────────────────────────

    async def geocode_address(self, address: str) -> Optional[dict]:
        """Convert a place name or address to lat/lng using Google Geocoding."""
        if not self.is_available:
            return None

        params = {
            "address": address,
            "key": self._api_key,
            "region": "np",
        }

        try:
            async with httpx.AsyncClient() as client:
                resp = await client.get(GEOCODE_URL, params=params, timeout=10)
                data = resp.json()
        except Exception as e:
            print(f"[GoogleMaps] Geocode error: {e}")
            return None

        status = data.get("status", "")
        self._health_status = self._map_status_to_health(status)

        if status != "OK" or not data.get("results"):
            return None

        result = data["results"][0]
        loc = result["geometry"]["location"]
        return {
            "formatted_address": result.get("formatted_address", ""),
            "latitude": loc["lat"],
            "longitude": loc["lng"],
            "place_id": result.get("place_id", ""),
        }

    # Backwards-compatible alias used by older callers.
    async def geocode(self, address: str) -> Optional[dict]:
        return await self.geocode_address(address)

    async def reverse_geocode(self, lat: float, lng: float) -> Optional[dict]:
        """Convert lat/lng into a human-readable Nepali address."""
        if not self.is_available:
            return None

        params = {
            "latlng": f"{lat},{lng}",
            "key": self._api_key,
            "region": "np",
            "language": "en",
        }

        try:
            async with httpx.AsyncClient() as client:
                resp = await client.get(GEOCODE_URL, params=params, timeout=10)
                data = resp.json()
        except Exception as e:
            print(f"[GoogleMaps] Reverse geocode error: {e}")
            return None

        status = data.get("status", "")
        self._health_status = self._map_status_to_health(status)

        if status != "OK" or not data.get("results"):
            return None

        result = data["results"][0]
        return {
            "formatted_address": result.get("formatted_address", ""),
            "latitude": lat,
            "longitude": lng,
            "place_id": result.get("place_id", ""),
        }

    # ── Places Autocomplete ─────────────────────────────────────

    async def autocomplete_places(
        self,
        query: str,
        limit: int = 5,
    ) -> list[dict]:
        """Suggest place completions biased to the Kathmandu valley.

        Results are restricted to Nepal and biased to a 20 km circle around
        Kathmandu so the typeahead always surfaces local landmarks first.
        """
        if not self.is_available or not query.strip():
            return []

        params = {
            "input": query,
            "key": self._api_key,
            "components": "country:np",
            "location": f"{KATHMANDU_LAT},{KATHMANDU_LNG}",
            "radius": str(KATHMANDU_RADIUS_METERS),
            "language": "en",
        }

        try:
            async with httpx.AsyncClient() as client:
                resp = await client.get(
                    PLACES_AUTOCOMPLETE_URL,
                    params=params,
                    timeout=10,
                )
                data = resp.json()
        except Exception as e:
            print(f"[GoogleMaps] Autocomplete error: {e}")
            return []

        status = data.get("status", "")
        self._health_status = self._map_status_to_health(status)

        if status not in ("OK", "ZERO_RESULTS"):
            return []

        predictions = data.get("predictions", [])[:limit]
        return [
            {
                "description": p.get("description", ""),
                "place_id": p.get("place_id", ""),
                "main_text": (p.get("structured_formatting") or {}).get(
                    "main_text", ""
                ),
                "secondary_text": (p.get("structured_formatting") or {}).get(
                    "secondary_text", ""
                ),
            }
            for p in predictions
        ]

    # ── Traffic layer helper ────────────────────────────────────

    def get_traffic_layer_url(self) -> Optional[dict]:
        """Return a descriptor of how to render Google's traffic layer.

        Google Maps doesn't expose a raw traffic tile URL for third-party use,
        and the Flutter app already has `trafficEnabled: true` on its
        [GoogleMap] widget which uses the native SDK's live traffic overlay.
        So for native clients we just tell them to use that, and for web
        clients we return the JS API URL.
        """
        if not self.is_available:
            return None

        return {
            "native_sdk": {
                "android_ios": "Set `trafficEnabled: true` on google_maps_flutter",
                "note": "Native SDKs render Google's live traffic overlay directly",
            },
            "web_js_api_url": (
                f"https://maps.googleapis.com/maps/api/js?key={self._api_key}"
                f"&libraries=places&region=NP&language=en"
            ),
        }


# Singleton instance
google_maps_service = GoogleMapsService()
