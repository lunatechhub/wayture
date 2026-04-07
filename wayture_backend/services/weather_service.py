from typing import Optional

import httpx

# Open-Meteo: completely FREE, no API key needed
OPEN_METEO_URL = "https://api.open-meteo.com/v1/forecast"


class WeatherService:

    async def get_weather(self, lat: float, lng: float) -> Optional[dict]:
        """Fetch current weather from Open-Meteo (free, no key)."""
        params = {
            "latitude": lat,
            "longitude": lng,
            "current_weather": "true",
            "hourly": "precipitation,weathercode,visibility",
            "timezone": "Asia/Kathmandu",
            "forecast_days": 1,
        }
        try:
            async with httpx.AsyncClient() as client:
                resp = await client.get(OPEN_METEO_URL, params=params, timeout=10)
                data = resp.json()

            if "current_weather" not in data:
                return None

            current = data["current_weather"]
            weather_code = current.get("weathercode", 0)
            temperature = current.get("temperature", 0)
            wind_speed = current.get("windspeed", 0)

            # Check hourly precipitation for current hour
            hourly = data.get("hourly", {})
            precip_values = hourly.get("precipitation", [])
            visibility_values = hourly.get("visibility", [])

            # Use first value as current approximation
            current_precip = precip_values[0] if precip_values else 0
            current_visibility = visibility_values[0] if visibility_values else 10000

            is_raining = current_precip > 0 or weather_code in (
                51, 53, 55,  # drizzle
                61, 63, 65,  # rain
                80, 81, 82,  # rain showers
                95, 96, 99,  # thunderstorm
            )

            description = self._weather_code_to_description(weather_code)

            return {
                "is_raining": is_raining,
                "weather_description": description,
                "temperature": temperature,
                "wind_speed_kmh": wind_speed,
                "precipitation_mm": current_precip,
                "visibility_m": current_visibility,
                "weather_code": weather_code,
            }

        except Exception as e:
            print(f"[Open-Meteo] Weather fetch failed: {e}")
            return None

    def get_congestion_factor(self, weather: Optional[dict]) -> tuple[float, str]:
        """Return a multiplier (1.0-1.5) and label based on weather.
        Bad weather increases congestion prediction.
        """
        if not weather:
            return 1.0, "clear"

        code = weather.get("weather_code", 0)
        visibility = weather.get("visibility_m", 10000)

        # Thunderstorm
        if code in (95, 96, 99):
            return 1.5, "thunderstorm"
        # Rain (moderate/heavy)
        if code in (63, 65, 81, 82):
            return 1.35, "heavy_rain"
        # Light rain / drizzle
        if code in (51, 53, 55, 61, 80):
            return 1.2, "light_rain"
        # Snow
        if code in (71, 73, 75, 77, 85, 86):
            return 1.4, "snow"
        # Fog / low visibility
        if code in (45, 48) or (visibility and visibility < 1000):
            return 1.25, "fog"

        return 1.0, "clear"

    @staticmethod
    def _weather_code_to_description(code: int) -> str:
        """WMO weather code to human-readable description."""
        descriptions = {
            0: "Clear sky",
            1: "Mainly clear",
            2: "Partly cloudy",
            3: "Overcast",
            45: "Foggy",
            48: "Depositing rime fog",
            51: "Light drizzle",
            53: "Moderate drizzle",
            55: "Dense drizzle",
            61: "Slight rain",
            63: "Moderate rain",
            65: "Heavy rain",
            71: "Slight snow",
            73: "Moderate snow",
            75: "Heavy snow",
            77: "Snow grains",
            80: "Slight rain showers",
            81: "Moderate rain showers",
            82: "Violent rain showers",
            85: "Slight snow showers",
            86: "Heavy snow showers",
            95: "Thunderstorm",
            96: "Thunderstorm with slight hail",
            99: "Thunderstorm with heavy hail",
        }
        return descriptions.get(code, "Unknown")


weather_service = WeatherService()
