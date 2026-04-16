from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager

from routers import auth, prediction, reports, notifications, traffic, ratings, maps
from services.firebase_service import firebase_service
from services.groq_service import groq_service
from services.maps_service import maps_service
from services.weather_service import weather_service
from services.google_maps_service import GoogleMapsHealth, google_maps_service
from services.ml_service import ml_service
from models.schemas import GeocodeResult


@asynccontextmanager
async def lifespan(app: FastAPI):
    print("=" * 50)
    print("  Wayture API - Starting up")
    print("=" * 50)
    print("[OK] OSRM routing — free, no key needed")
    print("[OK] Nominatim geocoding — free, no key needed")
    print("[OK] Open-Meteo weather — free, no key needed")

    # Probe Google Maps with one cheap live call so the /health endpoint
    # can report "connected" vs "invalid api key" vs "quota exceeded" without
    # spending quota on every /health request.
    if google_maps_service.is_available:
        probe = await google_maps_service.probe_connection()
        if probe == GoogleMapsHealth.CONNECTED:
            print("[OK] Google Maps — key verified (connected)")
        elif probe == GoogleMapsHealth.INVALID_KEY:
            print("[ERROR] Google Maps — REQUEST_DENIED")
            print("        Your key works for Maps SDK (mobile) but the server-side APIs are denied.")
            print("        Go to https://console.cloud.google.com → APIs & Services → Library")
            print("        Enable: Geocoding API, Directions API, Places API, Distance Matrix API")
            print("        Then restart this server. Routing will use OSRM fallback until fixed.")
        elif probe == GoogleMapsHealth.QUOTA_EXCEEDED:
            print("[WARNING] Google Maps — quota exceeded, will fall back to OSRM")
        else:
            print(f"[WARNING] Google Maps — probe returned: {probe}")
    else:
        print("[WARNING] Google Maps API — GOOGLE_MAPS_API_KEY not set, /route will use OSRM fallback")

    if groq_service.is_available:
        print("[OK] Groq AI — API key loaded")
    else:
        print("[WARNING] Groq AI — no API key found, AI insights disabled")

    if ml_service.is_available:
        print("[OK] ML service — scikit-learn available")
    else:
        print("[WARNING] ML service — scikit-learn not installed, predictions use rule-based fallback")

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
app.include_router(traffic.router, tags=["Traffic Data"])
app.include_router(ratings.router, prefix="/ratings", tags=["Ratings"])
# maps router keeps /route at the top level (for Flutter backward-compat)
# and exposes /maps/test for operator smoke tests.
app.include_router(maps.router, tags=["Maps"])


@app.get("/")
async def root():
    gmaps_health = google_maps_service.health_status
    gmaps_connected = gmaps_health == GoogleMapsHealth.CONNECTED
    gmaps_invalid = gmaps_health == GoogleMapsHealth.INVALID_KEY

    gmaps_display = gmaps_health
    if gmaps_invalid:
        gmaps_display = (
            "key loaded but server APIs denied — enable Geocoding API, "
            "Directions API, Places API in Google Cloud Console"
        )

    return {
        "message": "Wayture API is running",
        "status": "ok",
        "firebase": "connected" if firebase_service.is_initialized else "not connected",
        "services": {
            "routing": "Google Directions API" if gmaps_connected else "OSRM (free fallback)",
            "google_maps": gmaps_display,
            "geocoding": "Google Geocoding" if gmaps_connected else "Nominatim (free fallback)",
            "places": "Google Places" if gmaps_connected else "disabled (enable Places API)",
            "directions": "Google Directions API" if gmaps_connected else "OSRM (free fallback)",
            "weather": "Open-Meteo (free)",
            "tiles": "OpenStreetMap (free)",
            "ai_insights": "Groq" if groq_service.is_available else "disabled",
            "ml_prediction": "trained" if ml_service.is_trained else ("available" if ml_service.is_available else "disabled"),
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
