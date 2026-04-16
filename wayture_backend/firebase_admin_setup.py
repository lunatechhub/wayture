"""Firebase Admin SDK initialization — single source of truth."""
import os
import firebase_admin
from firebase_admin import credentials
from dotenv import load_dotenv

load_dotenv()

def initialize_firebase():
    """Initialize Firebase Admin if not already done. Returns the app."""
    if firebase_admin._apps:
        return firebase_admin.get_app()
    cred_path = os.getenv("FIREBASE_CREDENTIALS_PATH", "firebase_credentials.json")
    if not os.path.isabs(cred_path):
        cred_path = os.path.abspath(cred_path)
    if not os.path.exists(cred_path):
        raise FileNotFoundError(
            f"Firebase credentials not found at: {cred_path}\n"
            "Place firebase_credentials.json in wayture_backend/ or set FIREBASE_CREDENTIALS_PATH"
        )
    cred = credentials.Certificate(cred_path)
    return firebase_admin.initialize_app(cred)
