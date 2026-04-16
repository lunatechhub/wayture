"""Simple ML-based traffic congestion predictor.

Uses scikit-learn RandomForestClassifier trained on historical traffic data
stored in Firestore. Features: hour, day_of_week, latitude, longitude,
is_peak_hour, is_weekend. Target: congestion level (low/medium/high).

The model is trained lazily on first prediction request or when explicitly
triggered via the /traffic/train-model endpoint.
"""

import numpy as np
from datetime import datetime
from typing import Optional

# scikit-learn imports — wrapped so the server still starts if sklearn
# is not installed (just ML features will be disabled)
try:
    from sklearn.ensemble import RandomForestClassifier, RandomForestRegressor
    from sklearn.preprocessing import LabelEncoder
    ML_AVAILABLE = True
except ImportError:
    ML_AVAILABLE = False
    print("[WARNING] scikit-learn not installed — ML predictions disabled")


# Kathmandu peak hours
MORNING_PEAK = (7, 10)   # 7 AM – 10 AM
EVENING_PEAK = (16, 19)  # 4 PM – 7 PM

# Day name → number mapping
DAY_MAP = {
    "Monday": 0, "Tuesday": 1, "Wednesday": 2, "Thursday": 3,
    "Friday": 4, "Saturday": 5, "Sunday": 6,
}


class MLService:
    """Traffic congestion predictor using Random Forest."""

    def __init__(self):
        self._congestion_model: Optional[object] = None  # RandomForestClassifier
        self._speed_model: Optional[object] = None       # RandomForestRegressor
        self._label_encoder: Optional[object] = None     # LabelEncoder
        self._is_trained = False
        self._training_samples = 0

    @property
    def is_available(self) -> bool:
        return ML_AVAILABLE

    @property
    def is_trained(self) -> bool:
        return self._is_trained

    # ── Feature Engineering ─────────────────────────────────────

    @staticmethod
    def _is_peak_hour(hour: int) -> int:
        """Return 1 if the hour falls within Kathmandu peak traffic hours."""
        if MORNING_PEAK[0] <= hour < MORNING_PEAK[1]:
            return 1
        if EVENING_PEAK[0] <= hour < EVENING_PEAK[1]:
            return 1
        return 0

    @staticmethod
    def _is_weekend(day_of_week: str) -> int:
        """Return 1 if Saturday (Nepal weekend). Sunday is a workday in Nepal."""
        return 1 if day_of_week.lower() == "saturday" else 0

    def _extract_features(self, record: dict) -> list[float]:
        """Convert a traffic record into a feature vector.

        Features: [hour, day_num, latitude, longitude, is_peak, is_weekend]
        """
        hour = record.get("hour", 12)
        day_name = record.get("day_of_week", "Monday")
        day_num = DAY_MAP.get(day_name, 0)
        lat = record.get("latitude", 27.7172)
        lng = record.get("longitude", 85.3240)
        is_peak = self._is_peak_hour(hour)
        is_wknd = self._is_weekend(day_name)

        return [hour, day_num, lat, lng, is_peak, is_wknd]

    # ── Training ────────────────────────────────────────────────

    def train(self, records: list[dict]) -> dict:
        """Train the model on historical traffic data from Firestore.

        Args:
            records: List of traffic documents, each containing at least:
                     hour, day_of_week, latitude, longitude,
                     congestion_level, average_speed

        Returns:
            Training summary dict.
        """
        if not ML_AVAILABLE:
            return {"status": "error", "message": "scikit-learn not installed"}

        if len(records) < 5:
            return {"status": "error", "message": f"Need at least 5 records, got {len(records)}"}

        # Build feature matrix and target arrays
        X = []
        y_congestion = []
        y_speed = []

        for rec in records:
            features = self._extract_features(rec)
            X.append(features)
            y_congestion.append(rec.get("congestion_level", "low"))
            y_speed.append(rec.get("average_speed_kmh", rec.get("average_speed", 30.0)))

        X = np.array(X)
        y_speed = np.array(y_speed, dtype=float)

        # Encode congestion labels: low=0, medium=1, high=2
        self._label_encoder = LabelEncoder()
        y_congestion_encoded = self._label_encoder.fit_transform(y_congestion)

        # Train congestion classifier
        self._congestion_model = RandomForestClassifier(
            n_estimators=50,
            max_depth=10,
            random_state=42,
        )
        self._congestion_model.fit(X, y_congestion_encoded)

        # Train speed regressor
        self._speed_model = RandomForestRegressor(
            n_estimators=50,
            max_depth=10,
            random_state=42,
        )
        self._speed_model.fit(X, y_speed)

        self._is_trained = True
        self._training_samples = len(records)

        # Feature importances for interpretability
        feature_names = ["hour", "day_of_week", "latitude", "longitude", "is_peak_hour", "is_weekend"]
        importances = self._congestion_model.feature_importances_
        top_features = sorted(
            zip(feature_names, importances),
            key=lambda x: x[1],
            reverse=True,
        )

        return {
            "status": "ok",
            "samples_trained": len(records),
            "congestion_classes": list(self._label_encoder.classes_),
            "feature_importances": {name: round(imp, 3) for name, imp in top_features},
        }

    # ── Prediction ──────────────────────────────────────────────

    def predict(
        self,
        location: str,
        latitude: float,
        longitude: float,
        hour: Optional[int] = None,
        day_of_week: Optional[str] = None,
    ) -> dict:
        """Predict congestion level and speed for a location at a given time.

        Args:
            location: Location name (for display).
            latitude: GPS latitude.
            longitude: GPS longitude.
            hour: Hour of day (0-23). Defaults to current hour.
            day_of_week: Day name. Defaults to current day.

        Returns:
            Prediction dict with congestion level, speed, confidence, factors.
        """
        if not ML_AVAILABLE:
            return self._fallback_prediction(location, latitude, longitude, hour, day_of_week)

        if not self._is_trained:
            return self._fallback_prediction(location, latitude, longitude, hour, day_of_week)

        now = datetime.now()
        if hour is None:
            hour = now.hour
        if day_of_week is None:
            day_of_week = now.strftime("%A")

        record = {
            "hour": hour,
            "day_of_week": day_of_week,
            "latitude": latitude,
            "longitude": longitude,
        }
        features = np.array([self._extract_features(record)])

        # Predict congestion level
        congestion_encoded = self._congestion_model.predict(features)[0]
        congestion_label = self._label_encoder.inverse_transform([congestion_encoded])[0]

        # Prediction probabilities for confidence
        proba = self._congestion_model.predict_proba(features)[0]
        confidence = float(max(proba))

        # Predict speed
        predicted_speed = float(self._speed_model.predict(features)[0])
        predicted_speed = max(0.0, round(predicted_speed, 1))

        # Explain factors
        factors = []
        if self._is_peak_hour(hour):
            factors.append(f"Peak hour ({hour}:00) — higher congestion expected")
        else:
            factors.append(f"Off-peak hour ({hour}:00) — lighter traffic expected")

        if self._is_weekend(day_of_week):
            factors.append("Saturday (Nepal weekend) — reduced traffic")
        else:
            factors.append(f"{day_of_week} — regular workday traffic")

        if congestion_label == "high":
            factors.append("Model predicts heavy congestion — use alternate routes")
        elif congestion_label == "medium":
            factors.append("Model predicts moderate congestion — allow extra time")
        else:
            factors.append("Model predicts smooth traffic flow")

        return {
            "location": location,
            "predicted_congestion": congestion_label,
            "predicted_speed": predicted_speed,
            "confidence": round(confidence, 2),
            "hour": hour,
            "day_of_week": day_of_week,
            "factors": factors,
            "model_type": "RandomForest",
            "training_samples": self._training_samples,
        }

    # ── Rule-based fallback when ML is not trained ──────────────

    def _fallback_prediction(
        self,
        location: str,
        latitude: float,
        longitude: float,
        hour: Optional[int] = None,
        day_of_week: Optional[str] = None,
    ) -> dict:
        """Simple rule-based prediction when ML model is not available."""
        now = datetime.now()
        if hour is None:
            hour = now.hour
        if day_of_week is None:
            day_of_week = now.strftime("%A")

        is_peak = self._is_peak_hour(hour)
        is_wknd = self._is_weekend(day_of_week)

        factors = []
        if is_peak and not is_wknd:
            congestion = "high"
            speed = 8.0
            factors.append(f"Peak hour ({hour}:00) on {day_of_week} — heavy traffic expected")
        elif is_peak and is_wknd:
            congestion = "medium"
            speed = 18.0
            factors.append(f"Peak hour on Saturday — moderate traffic")
        elif not is_peak and not is_wknd:
            congestion = "medium" if 10 <= hour <= 16 else "low"
            speed = 22.0 if congestion == "medium" else 35.0
            factors.append(f"Off-peak on {day_of_week}")
        else:
            congestion = "low"
            speed = 35.0
            factors.append("Weekend off-peak — light traffic")

        factors.append("(Rule-based fallback — upload traffic data to enable ML)")

        return {
            "location": location,
            "predicted_congestion": congestion,
            "predicted_speed": speed,
            "confidence": 0.5,
            "hour": hour,
            "day_of_week": day_of_week,
            "factors": factors,
            "model_type": "rule_based_fallback",
            "training_samples": 0,
        }


# Singleton instance
ml_service = MLService()
