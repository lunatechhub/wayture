"""Groq AI service — generates traffic insights and route suggestions using LLM."""

import os
import httpx
from dotenv import load_dotenv

load_dotenv()


class GroqService:
    _api_key: str | None = os.getenv("GROQ_API_KEY")
    _base_url = "https://api.groq.com/openai/v1/chat/completions"
    _model = "llama-3.3-70b-versatile"

    @property
    def is_available(self) -> bool:
        return bool(self._api_key)

    async def _call_groq(self, system: str, user: str, max_tokens: int = 200) -> str | None:
        """Low-level Groq API call."""
        if not self._api_key:
            return None
        try:
            async with httpx.AsyncClient() as client:
                response = await client.post(
                    self._base_url,
                    headers={
                        "Authorization": f"Bearer {self._api_key}",
                        "Content-Type": "application/json",
                    },
                    json={
                        "model": self._model,
                        "messages": [
                            {"role": "system", "content": system},
                            {"role": "user", "content": user},
                        ],
                        "max_tokens": max_tokens,
                        "temperature": 0.7,
                    },
                    timeout=10.0,
                )
                if response.status_code == 200:
                    data = response.json()
                    return data["choices"][0]["message"]["content"].strip()
        except Exception as e:
            print(f"[GroqService] API error: {e}")
        return None

    async def get_traffic_insight(
        self,
        *,
        congestion_level: str,
        congestion_reason: str,
        score: float,
        weather_label: str,
        reports_count: int,
        distance_km: float | None = None,
        duration_min: float | None = None,
        is_raining: bool = False,
        main_route: dict | None = None,
        alternate_routes: list[dict] | None = None,
    ) -> dict[str, str | None]:
        """Return AI insight + route suggestion based on traffic and route data.

        Returns:
            {
                "insight": "...",            # General traffic advice
                "route_suggestion": "...",   # Which route to take and why
            }
        """
        if not self._api_key:
            return {"insight": None, "route_suggestion": None}

        # --- Build route comparison data ---
        routes_text = ""
        if main_route:
            routes_text += (
                f"\nMain Route (Route 0): "
                f"{main_route.get('distance_km', '?'):.1f} km, "
                f"{main_route.get('duration_minutes', '?'):.0f} min, "
                f"congestion: {main_route.get('congestion_level', '?')}"
            )
        if alternate_routes:
            for i, alt in enumerate(alternate_routes):
                routes_text += (
                    f"\nAlternate Route {i + 1}: "
                    f"{alt.get('distance_km', '?'):.1f} km, "
                    f"{alt.get('duration_minutes', '?'):.0f} min, "
                    f"congestion: {alt.get('congestion_level', '?')}"
                )

        prompt = (
            f"Congestion Level: {congestion_level}\n"
            f"Score: {score:.0f}/100\n"
            f"Reason: {congestion_reason}\n"
            f"Weather: {weather_label}\n"
            f"Raining: {'Yes' if is_raining else 'No'}\n"
            f"Nearby Reports: {reports_count}\n"
        )
        if distance_km is not None:
            prompt += f"Overall Distance: {distance_km:.1f} km\n"
        if duration_min is not None:
            prompt += f"Estimated Time: {duration_min:.0f} minutes\n"
        if routes_text:
            prompt += f"\nAvailable Routes:{routes_text}\n"

        prompt += (
            "\nRespond in EXACTLY this format (two lines only):\n"
            "INSIGHT: <one practical sentence about current traffic conditions>\n"
            "ROUTE: <one sentence recommending which route to take and why>"
        )

        system = (
            "You are a concise Kathmandu traffic advisor. "
            "Analyze traffic data and available routes. "
            "Always suggest the best route among the options. "
            "If congestion is yellow or red on the main route, strongly recommend an alternate. "
            "Reply ONLY in the exact two-line format requested. "
            "No greetings, no bullet points, no markdown."
        )

        result = await self._call_groq(system, prompt, max_tokens=200)

        insight = None
        route_suggestion = None

        if result:
            for line in result.split("\n"):
                line = line.strip()
                if line.upper().startswith("INSIGHT:"):
                    insight = line[len("INSIGHT:"):].strip()
                elif line.upper().startswith("ROUTE:"):
                    route_suggestion = line[len("ROUTE:"):].strip()

            # Fallback: if parsing failed, use full response as insight
            if not insight and not route_suggestion:
                insight = result

        return {"insight": insight, "route_suggestion": route_suggestion}


groq_service = GroqService()
