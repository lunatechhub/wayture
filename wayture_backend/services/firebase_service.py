import os
from datetime import datetime, timezone
from math import radians, sin, cos, sqrt, atan2

import firebase_admin
from firebase_admin import auth as firebase_auth, credentials
from dotenv import load_dotenv

load_dotenv()


class FirebaseService:
    def __init__(self):
        self._db = None
        self._initialized = False
        self._init_error: str | None = None

    def initialize(self):
        """Initialize Firebase app and async Firestore client.
        Called explicitly from main.py lifespan so import never crashes.
        """
        if self._initialized:
            return

        cred_path = os.getenv("FIREBASE_CREDENTIALS_PATH", "firebase_credentials.json")

        if not os.path.isabs(cred_path):
            cred_path = os.path.abspath(cred_path)

        if not os.path.exists(cred_path):
            self._init_error = (
                f"Firebase credentials file not found at: {cred_path}\n"
                "  -> Place your firebase_credentials.json in the wayture_backend/ folder\n"
                "  -> Or update FIREBASE_CREDENTIALS_PATH in .env"
            )
            print(f"[WARNING] {self._init_error}")
            return

        try:
            if not firebase_admin._apps:
                cred = credentials.Certificate(cred_path)
                firebase_admin.initialize_app(cred)

            from google.cloud.firestore_v1 import AsyncClient

            app = firebase_admin.get_app()
            google_cred = app.credential.get_credential()
            project_id = app.project_id
            self._db = AsyncClient(credentials=google_cred, project=project_id)
            self._initialized = True
            print(f"[OK] Firebase initialized (project: {project_id})")
        except Exception as e:
            self._init_error = str(e)
            print(f"[ERROR] Firebase initialization failed: {e}")

    @property
    def db(self):
        if not self._initialized:
            raise RuntimeError(
                f"Firebase is not initialized. {self._init_error or 'Call initialize() first.'}"
            )
        return self._db

    # --- Health Check ---

    async def health_check(self):
        """Verify Firestore is reachable with a lightweight read (no junk data)."""
        try:
            # Read-only check: list up to 1 doc from any collection
            docs = self.db.collection("settings").limit(1).stream()
            async for _ in docs:
                pass
            return True
        except Exception as e:
            error_msg = str(e)
            if "SERVICE_DISABLED" in error_msg or "has not been used" in error_msg:
                print(
                    "[ACTION REQUIRED] Cloud Firestore API is not enabled.\n"
                    "  -> Go to: https://console.developers.google.com/apis/api/"
                    "firestore.googleapis.com/overview?project=webture-a80f6\n"
                    "  -> Click 'Enable API', wait 1-2 minutes, then restart the server."
                )
            raise

    # --- Users ---

    async def create_user(self, uid: str, data: dict) -> dict:
        doc_ref = self.db.collection("users").document(uid)
        data["created_at"] = datetime.now(timezone.utc)
        await doc_ref.set(data)
        return {**data, "uid": uid}

    async def get_user(self, uid: str) -> dict | None:
        doc = await self.db.collection("users").document(uid).get()
        return doc.to_dict() if doc.exists else None

    async def update_user(self, uid: str, data: dict):
        await self.db.collection("users").document(uid).update(data)

    # --- Location ---

    async def update_location(self, uid: str, data: dict):
        doc_ref = self.db.collection("locations").document(uid)
        data["updated_at"] = datetime.now(timezone.utc)
        await doc_ref.set(data, merge=True)

    async def get_nearby_locations(self, lat: float, lng: float, radius_km: float) -> list[dict]:
        """Get all locations and filter by haversine distance."""
        docs = self.db.collection("locations").stream()
        results = []
        async for doc in docs:
            d = doc.to_dict()
            if "latitude" not in d or "longitude" not in d:
                continue
            dist = self._haversine(lat, lng, d["latitude"], d["longitude"])
            if dist <= radius_km:
                results.append({**d, "uid": doc.id, "distance_km": dist})
        return results

    # --- CommunityReports ---

    async def create_report(self, uid: str, data: dict) -> str:
        data["uid"] = uid
        data["created_at"] = datetime.now(timezone.utc)
        data["upvotes"] = 0
        _, doc_ref = await self.db.collection("communityReports").add(data)
        return doc_ref.id

    async def get_nearby_reports(self, lat: float, lng: float, radius_km: float) -> list[dict]:
        docs = self.db.collection("communityReports").stream()
        results = []
        async for doc in docs:
            d = doc.to_dict()
            if "latitude" not in d or "longitude" not in d:
                continue
            dist = self._haversine(lat, lng, d["latitude"], d["longitude"])
            if dist <= radius_km:
                results.append({**d, "id": doc.id})
        return results

    # --- Routes ---

    async def save_route(self, uid: str, data: dict) -> str:
        data["uid"] = uid
        data["created_at"] = datetime.now(timezone.utc)
        _, doc_ref = await self.db.collection("routes").add(data)
        return doc_ref.id

    async def get_user_routes(self, uid: str) -> list[dict]:
        docs = self.db.collection("routes").where("uid", "==", uid).stream()
        return [{**doc.to_dict(), "id": doc.id} async for doc in docs]

    # --- Notifications ---

    async def create_notification(self, uid: str, title: str, body: str) -> str:
        data = {
            "uid": uid,
            "title": title,
            "body": body,
            "read": False,
            "created_at": datetime.now(timezone.utc),
        }
        _, doc_ref = await self.db.collection("notifications").add(data)
        return doc_ref.id

    async def get_unread_notifications(self, uid: str) -> list[dict]:
        docs = (
            self.db.collection("notifications")
            .where("uid", "==", uid)
            .where("read", "==", False)
            .order_by("created_at")
            .stream()
        )
        return [{**doc.to_dict(), "id": doc.id} async for doc in docs]

    async def mark_notifications_read(self, notification_ids: list[str]):
        batch = self.db.batch()
        for nid in notification_ids:
            ref = self.db.collection("notifications").document(nid)
            batch.update(ref, {"read": True})
        await batch.commit()

    # --- Traffic Data ---

    async def store_traffic_data(self, data: dict) -> str:
        """Store a single traffic data record in Firestore."""
        data["timestamp"] = datetime.now(timezone.utc)
        _, doc_ref = await self.db.collection("traffic_data").add(data)
        return doc_ref.id

    async def store_traffic_batch(self, records: list[dict]) -> int:
        """Store multiple traffic records in a single batch write."""
        batch = self.db.batch()
        count = 0
        for rec in records:
            rec["timestamp"] = datetime.now(timezone.utc)
            doc_ref = self.db.collection("traffic_data").document()
            batch.set(doc_ref, rec)
            count += 1
            # Firestore batch limit is 500 per commit
            if count % 450 == 0:
                await batch.commit()
                batch = self.db.batch()
        if count % 450 != 0:
            await batch.commit()
        return count

    async def get_all_traffic_data(self, limit: int = 500) -> list[dict]:
        """Fetch all traffic data, ordered by created_at descending."""
        query = (
            self.db.collection("traffic_data")
            .order_by("timestamp", direction="DESCENDING")
            .limit(limit)
        )
        docs = query.stream()
        return [{**doc.to_dict(), "id": doc.id} async for doc in docs]

    async def get_traffic_by_location(self, location: str) -> list[dict]:
        """Fetch traffic data for a specific location name.

        Traffic records are stored with `location_name` (see TrafficDataUpload),
        so we must filter on that field — filtering on "location" always
        returned zero docs and surfaced as a 404 to the Flutter client.
        """
        docs = (
            self.db.collection("traffic_data")
            .where("location_name", "==", location)
            .order_by("timestamp", direction="DESCENDING")
            .limit(100)
            .stream()
        )
        return [{**doc.to_dict(), "id": doc.id} async for doc in docs]

    async def store_realtime_update(self, data: dict) -> str:
        """Store or update a real-time traffic observation.

        Uses location name as document ID so each location has exactly
        one real-time record that gets overwritten with the latest data.
        """
        location = data.get("location_name", "unknown")
        doc_id = location.lower().replace(" ", "_")
        data["updated_at"] = datetime.now(timezone.utc)
        await self.db.collection("traffic_realtime").document(doc_id).set(data)
        return doc_id

    async def get_all_realtime_traffic(self) -> list[dict]:
        """Fetch all real-time traffic snapshots."""
        docs = self.db.collection("traffic_realtime").stream()
        return [{**doc.to_dict(), "id": doc.id} async for doc in docs]

    async def get_all_traffic_for_ml(self) -> list[dict]:
        """Fetch all historical traffic data for ML training (no limit)."""
        docs = self.db.collection("traffic_data").stream()
        results = []
        async for doc in docs:
            d = doc.to_dict()
            # Normalise datetime fields to avoid serialisation issues
            for key in ("created_at", "updated_at", "timestamp"):
                if key in d and hasattr(d[key], "isoformat"):
                    d[key] = d[key].isoformat()
            results.append(d)
        return results

    # --- Settings (Set collection) ---

    async def get_settings(self, uid: str) -> dict | None:
        doc = await self.db.collection("Settings").document(uid).get()
        return doc.to_dict() if doc.exists else None

    async def update_settings(self, uid: str, data: dict):
        await self.db.collection("Settings").document(uid).set(data, merge=True)

    # --- App Ratings ---

    async def store_rating(self, uid: str, data: dict) -> str:
        """Store or update a user's app rating in the appRatings collection."""
        data["uid"] = uid
        data["updated_at"] = datetime.now(timezone.utc)
        # Set created_at only on first write (check if doc exists)
        existing = await self.db.collection("appRatings").document(uid).get()
        if not existing.exists:
            data["created_at"] = datetime.now(timezone.utc)
        await self.db.collection("appRatings").document(uid).set(data, merge=True)
        return uid

    async def get_rating(self, uid: str) -> dict | None:
        """Fetch a single user's rating."""
        doc = await self.db.collection("appRatings").document(uid).get()
        return {**doc.to_dict(), "id": doc.id} if doc.exists else None

    async def get_all_ratings(self) -> list[dict]:
        """Fetch all app ratings for summary/display."""
        docs = self.db.collection("appRatings").stream()
        return [{**doc.to_dict(), "id": doc.id} async for doc in docs]

    # --- Incidents ---

    async def create_incident(self, data: dict) -> str:
        data["timestamp"] = datetime.now(timezone.utc)
        data["is_active"] = True
        _, doc_ref = await self.db.collection("incidents").add(data)
        return doc_ref.id

    async def get_active_incidents(self) -> list[dict]:
        docs = (
            self.db.collection("incidents")
            .where("is_active", "==", True)
            .stream()
        )
        return [{**doc.to_dict(), "id": doc.id} async for doc in docs]

    async def get_all_incidents(self) -> list[dict]:
        docs = self.db.collection("incidents").stream()
        return [{**doc.to_dict(), "id": doc.id} async for doc in docs]

    async def resolve_incident(self, incident_id: str):
        await self.db.collection("incidents").document(incident_id).update({
            "is_active": False,
            "resolved_at": datetime.now(timezone.utc),
        })

    # --- Nepal Locations ---

    async def add_nepal_location(self, data: dict) -> str:
        doc_id = data.get("location_name", "unknown").lower().replace(" ", "_").replace(",", "")
        data["created_at"] = datetime.now(timezone.utc)
        await self.db.collection("nepal_locations").document(doc_id).set(data)
        return doc_id

    async def get_nepal_locations(self) -> list[dict]:
        docs = self.db.collection("nepal_locations").stream()
        return [{**doc.to_dict(), "id": doc.id} async for doc in docs]

    # --- Route Suggestions ---

    async def add_route_suggestion(self, data: dict) -> str:
        data["created_at"] = datetime.now(timezone.utc)
        _, doc_ref = await self.db.collection("route_suggestions").add(data)
        return doc_ref.id

    async def get_route_suggestions(self) -> list[dict]:
        docs = self.db.collection("route_suggestions").stream()
        return [{**doc.to_dict(), "id": doc.id} async for doc in docs]

    # --- Seed Data ---

    async def clear_collection(self, collection_name: str):
        """Delete all documents in a collection (for re-seeding)."""
        docs = self.db.collection(collection_name).stream()
        batch = self.db.batch()
        count = 0
        async for doc in docs:
            batch.delete(doc.reference)
            count += 1
            if count % 450 == 0:
                await batch.commit()
                batch = self.db.batch()
        if count % 450 != 0:
            await batch.commit()
        return count

    # --- Helpers ---

    @staticmethod
    def _haversine(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
        """Distance in km between two lat/lng points."""
        R = 6371.0
        dlat = radians(lat2 - lat1)
        dlon = radians(lon2 - lon1)
        a = sin(dlat / 2) ** 2 + cos(radians(lat1)) * cos(radians(lat2)) * sin(dlon / 2) ** 2
        return R * 2 * atan2(sqrt(a), sqrt(1 - a))

    def verify_firebase_token(self, token: str) -> dict:
        """Verify Firebase ID token and return decoded claims."""
        if not self._initialized:
            raise RuntimeError("Firebase is not initialized. Cannot verify tokens.")
        return firebase_auth.verify_id_token(token)

    @property
    def is_initialized(self) -> bool:
        return self._initialized


firebase_service = FirebaseService()
