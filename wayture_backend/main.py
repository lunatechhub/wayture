from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager

from routers import auth, prediction, reports, notifications
from services.firebase_service import firebase_service
from services.groq_service import groq_service
from services.maps_service import maps_service
from services.weather_service import weather_service
from models.schemas import GeocodeResult


@asynccontextmanager
async def lifespan(app: FastAPI):
    print("=" * 50)
    print("  Wayture API - Starting up")
    print("=" * 50)
    print("[OK] OSRM routing — free, no key needed")
    print("[OK] Nominatim geocoding — free, no key needed")
    print("[OK] Open-Meteo weather — free, no key needed")

    if groq_service.is_available:
        print("[OK] Groq AI — API key loaded")
    else:
        print("[WARNING] Groq AI — no API key found, AI insights disabled")

    # Initialize Firebase
    firebase_service.initialize()

    # Health check Firestore
    if firebase_service.is_initialized:
        try:
            await firebase_service.health_check()
            print("[OK] Firestore health check passed")
        except Exception as e:
            print(f"[WARNING] Firestore health check failed: {e}")
    else:
        print("[WARNING] Firebase not initialized — auth/database endpoints will fail")

    print("=" * 50)
    print("  Wayture API ready at http://localhost:8000")
    print("  Docs at http://localhost:8000/docs")
    print("=" * 50)

    yield


app = FastAPI(
    title="Wayture API",
    description="Traffic Congestion Predictor for Kathmandu — 100% free APIs",
    version="1.0.0",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth.router, prefix="/auth", tags=["Auth"])
app.include_router(prediction.router, prefix="/prediction", tags=["Prediction"])
app.include_router(reports.router, prefix="/reports", tags=["Reports"])
app.include_router(notifications.router, prefix="/notifications", tags=["Notifications"])


@app.get("/")
async def root():
    return {
        "message": "Wayture API is running",
        "status": "ok",
        "firebase": "connected" if firebase_service.is_initialized else "not connected",
        "services": {
            "routing": "OSRM (free)",
            "geocoding": "Nominatim (free)",
            "weather": "Open-Meteo (free)",
            "tiles": "OpenStreetMap (free)",
            "ai_insights": "Groq" if groq_service.is_available else "disabled",
        },
    }


@app.get("/health")
async def health():
    return {"status": "healthy", "firebase": firebase_service.is_initialized}


@app.get("/geocode", response_model=list[GeocodeResult], tags=["Geocoding"])
async def geocode(q: str, limit: int = 5):
    """Search for places using Nominatim (free, no key). Biased toward Kathmandu."""
    results = await maps_service.geocode_place(q, limit=limit)
    return [GeocodeResult(**r) for r in results]
