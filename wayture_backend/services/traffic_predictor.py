"""Traffic congestion predictor for the Find Routes feature.

Loads a pre-trained scikit-learn model from `ml/traffic_model.pkl` when
present. If the file is missing or fails to load, silently falls back to a
rule-of-thumb heuristic based on how fast the route moves on average
(km / minute). This keeps the Find Routes demo working even before the
model has been trained.
"""

from __future__ import annotations

import os
import pickle
from pathlib import Path
from typing import Optional


# Path where we expect the trained model to live. Kept next to the backend
# so the file is easy to drop in during development.
MODEL_PATH = Path(__file__).resolve().parent.parent / "ml" / "traffic_model.pkl"


class TrafficPredictor:
    """Classifies a route segment as low / medium / high congestion."""

    def __init__(self) -> None:
        self._model = None
        self._load_model()

    # ── Loading ────────────────────────────────────────────────────────────

    def _load_model(self) -> None:
        """Try to load the pickled model — fail silently and use heuristic."""
        if not MODEL_PATH.exists():
            print(f"[traffic_predictor] No model at {MODEL_PATH} — using heuristic")
            return
        try:
            with open(MODEL_PATH, "rb") as f:
                self._model = pickle.load(f)
            print(f"[traffic_predictor] Loaded model from {MODEL_PATH}")
        except Exception as e:
            print(f"[traffic_predictor] Failed to load model: {e} — using heuristic")
            self._model = None

    @property
    def is_trained(self) -> bool:
        return self._model is not None

    # ── Prediction ─────────────────────────────────────────────────────────

    def classify(
        self,
        distance_km: float,
        duration_minutes: float,
        hour_of_day: Optional[int] = None,
    ) -> str:
        """Return one of: 'low', 'medium', 'high'.

        The classifier is deliberately tolerant — if the model is missing or
        raises, we fall back to a simple speed-based rule so the /find-routes
        endpoint never fails because of ML.
        """
        # Guard against divide-by-zero on same-point routes.
        if duration_minutes <= 0 or distance_km <= 0:
            return "low"

        avg_speed_kmh = (distance_km / duration_minutes) * 60

        # Prefer the trained model when available.
        if self._model is not None:
            try:
                features = [[distance_km, duration_minutes, avg_speed_kmh, hour_of_day or 12]]
                prediction = self._model.predict(features)[0]
                # Normalise a few common label formats.
                label = str(prediction).lower()
                if label in {"low", "medium", "high"}:
                    return label
                if label in {"0", "light"}:
                    return "low"
                if label in {"1", "moderate"}:
                    return "medium"
                if label in {"2", "heavy", "severe"}:
                    return "high"
            except Exception as e:
                print(f"[traffic_predictor] Model predict failed: {e} — using heuristic")

        # Heuristic: Kathmandu average speeds, with a time-of-day nudge.
        # Same average speed means different things depending on when you're
        # driving — 20 km/h at 8 AM is actually good (traffic clearing),
        # but 20 km/h at midnight is unusually slow (likely an incident).
        # Base thresholds:
        #   >= 25 km/h → flowing well (low)
        #   15–25      → moderate (medium)
        #   < 15       → stop-and-go (high)
        low_threshold = 25.0
        medium_threshold = 15.0

        if hour_of_day is not None:
            # Morning + evening rush — raise the bar: you need MORE speed
            # to qualify as "low" because congestion is the norm.
            if 7 <= hour_of_day <= 10 or 17 <= hour_of_day <= 20:
                low_threshold = 30.0
                medium_threshold = 18.0
            # Late-night + early-morning — lower the bar: even modest
            # speeds count as "low" because roads are empty anyway.
            elif hour_of_day >= 22 or hour_of_day <= 5:
                low_threshold = 20.0
                medium_threshold = 12.0

        if avg_speed_kmh >= low_threshold:
            return "low"
        if avg_speed_kmh >= medium_threshold:
            return "medium"
        return "high"

    # ── Color mapping for the UI ───────────────────────────────────────────

    @staticmethod
    def color_for(congestion: str) -> str:
        """Return a hex color string the Flutter app can parse directly."""
        return {
            "low": "#2ECC71",     # green  — fastest / least congested
            "medium": "#F39C12",  # orange — moderate traffic
            "high": "#E74C3C",    # red    — heavy traffic, avoid if possible
        }.get(congestion, "#3498DB")  # blue fallback


# Module-level singleton so the model is loaded only once at import time.
traffic_predictor = TrafficPredictor()
