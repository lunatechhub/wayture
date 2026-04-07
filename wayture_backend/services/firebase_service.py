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
        """Verify Firestore is reachable by writing a ping document."""
        try:
            doc_ref = self.db.collection("_health").document("ping")
            await doc_ref.set({"ts": datetime.now(timezone.utc)})
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
        doc_ref = self.db.collection("Users").document(uid)
        data["created_at"] = datetime.now(timezone.utc)
        await doc_ref.set(data)
        return {**data, "uid": uid}

    async def get_user(self, uid: str) -> dict | None:
        doc = await self.db.collection("Users").document(uid).get()
        return doc.to_dict() if doc.exists else None

    async def update_user(self, uid: str, data: dict):
        await self.db.collection("Users").document(uid).update(data)

    # --- Location ---

    async def update_location(self, uid: str, data: dict):
        doc_ref = self.db.collection("Location").document(uid)
        data["updated_at"] = datetime.now(timezone.utc)
        await doc_ref.set(data, merge=True)

    async def get_nearby_locations(self, lat: float, lng: float, radius_km: float) -> list[dict]:
        """Get all locations and filter by haversine distance."""
        docs = self.db.collection("Location").stream()
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
        _, doc_ref = await self.db.collection("CommunityReports").add(data)
        return doc_ref.id

    async def get_nearby_reports(self, lat: float, lng: float, radius_km: float) -> list[dict]:
        docs = self.db.collection("CommunityReports").stream()
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
        _, doc_ref = await self.db.collection("Routes").add(data)
        return doc_ref.id

    async def get_user_routes(self, uid: str) -> list[dict]:
        docs = self.db.collection("Routes").where("uid", "==", uid).stream()
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
        _, doc_ref = await self.db.collection("Notifications").add(data)
        return doc_ref.id

    async def get_unread_notifications(self, uid: str) -> list[dict]:
        docs = (
            self.db.collection("Notifications")
            .where("uid", "==", uid)
            .where("read", "==", False)
            .order_by("created_at")
            .stream()
        )
        return [{**doc.to_dict(), "id": doc.id} async for doc in docs]

    async def mark_notifications_read(self, notification_ids: list[str]):
        batch = self.db.batch()
        for nid in notification_ids:
            ref = self.db.collection("Notifications").document(nid)
            batch.update(ref, {"read": True})
        await batch.commit()

    # --- Settings (Set collection) ---

    async def get_settings(self, uid: str) -> dict | None:
        doc = await self.db.collection("Set").document(uid).get()
        return doc.to_dict() if doc.exists else None

    async def update_settings(self, uid: str, data: dict):
        await self.db.collection("Set").document(uid).set(data, merge=True)

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
