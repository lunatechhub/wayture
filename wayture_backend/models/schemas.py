from pydantic import BaseModel, Field
from typing import Optional
from datetime import datetime
from enum import Enum


# --- Enums ---

class CongestionLevel(str, Enum):
    LOW = "low"
    MEDIUM = "medium"
    HIGH = "high"
    SEVERE = "severe"


class ReportType(str, Enum):
    ACCIDENT = "accident"
    ROAD_CLOSURE = "road_closure"
    CONSTRUCTION = "construction"
    FLOODING = "flooding"
    TRAFFIC_JAM = "traffic_jam"
    OTHER = "other"


# --- Auth ---

class UserRegisterRequest(BaseModel):
    firebase_token: str
    name: str
    email: str
    phone: Optional[str] = None


class UserResponse(BaseModel):
    uid: str
    name: str
    email: str
    phone: Optional[str] = None
    created_at: datetime


class LoginRequest(BaseModel):
    firebase_token: str


class AuthResponse(BaseModel):
    uid: str
    name: str
    email: str
    message: str


# --- Location ---

class LocationUpdate(BaseModel):
    latitude: float = Field(..., ge=-90, le=90)
    longitude: float = Field(..., ge=-180, le=180)
    speed: Optional[float] = Field(None, ge=0, description="Speed in km/h")
    heading: Optional[float] = None
    timestamp: Optional[datetime] = None


# --- Prediction ---

class CongestionPredictionRequest(BaseModel):
    user_lat: float = Field(..., ge=-90, le=90)
    user_lng: float = Field(..., ge=-180, le=180)
    dest_lat: float = Field(..., ge=-90, le=90)
    dest_lng: float = Field(..., ge=-180, le=180)
    user_speed: Optional[float] = Field(None, ge=0, description="Current speed in km/h")


class RouteInfo(BaseModel):
    route_index: int
    distance_km: float
    duration_minutes: float
    points: list[list[float]]
    congestion_level: CongestionLevel
    steps: list[dict] = []


class CongestionPredictionResponse(BaseModel):
    congestion_level: CongestionLevel
    congestion_reason: str
    main_route: Optional[RouteInfo] = None
    alternate_routes: list[RouteInfo] = []
    weather_warning: Optional[str] = None
    estimated_time_minutes: Optional[float] = None
    nearby_reports_count: int = 0
    is_raining: bool = False
    temperature: Optional[float] = None
    ai_insight: Optional[str] = None
    ai_route_suggestion: Optional[str] = None


class TrafficStatusResponse(BaseModel):
    congestion_level: CongestionLevel
    color: str
    score: float = Field(..., ge=0, le=100)
    avg_speed_kmh: Optional[float] = None
    nearby_reports_count: int = 0
    stopped_vehicles_count: int = 0
    weather_factor: str = "clear"
    message: str


# --- Community Reports ---

class ReportCreateRequest(BaseModel):
    latitude: float = Field(..., ge=-90, le=90)
    longitude: float = Field(..., ge=-180, le=180)
    report_type: ReportType
    description: Optional[str] = Field(None, max_length=500)


class ReportResponse(BaseModel):
    id: str
    uid: str
    latitude: float
    longitude: float
    report_type: ReportType
    description: Optional[str] = None
    created_at: datetime
    upvotes: int = 0


class NearbyReportsRequest(BaseModel):
    latitude: float = Field(..., ge=-90, le=90)
    longitude: float = Field(..., ge=-180, le=180)
    radius_km: float = Field(default=2.0, ge=0.1, le=20.0)


# --- Geocoding ---

class GeocodeResult(BaseModel):
    name: str
    latitude: float
    longitude: float
    type: str = ""


# --- Notifications ---

class NotificationResponse(BaseModel):
    id: str
    uid: str
    title: str
    body: str
    read: bool = False
    created_at: datetime


class MarkReadRequest(BaseModel):
    notification_ids: list[str]


# --- Settings ---

class UserSettings(BaseModel):
    notifications_enabled: bool = True
    dark_mode: bool = False
    preferred_language: str = "en"
    alert_radius_km: float = Field(default=2.0, ge=0.5, le=10.0)


# --- Traffic Data ---

class TrafficDataUpload(BaseModel):
    """Single traffic observation — from Excel import, sensor, or manual entry."""
    location_name: str = Field(..., min_length=1, description="Location name, e.g. Koteshwor")
    latitude: float = Field(..., ge=-90, le=90)
    longitude: float = Field(..., ge=-180, le=180)
    congestion_level: CongestionLevel = CongestionLevel.LOW
    vehicle_count: int = Field(default=0, ge=0)
    average_speed_kmh: float = Field(default=30.0, ge=0, description="Average speed in km/h")
    hour: int = Field(default=0, ge=0, le=23, description="Hour of day (0-23)")
    day_of_week: str = Field(default="Monday", description="Day name e.g. Monday")
    date: Optional[str] = Field(None, description="Date string e.g. 2026-04-09")
    source: str = Field(default="manual", description="Data source: excel_import, realtime, manual")


class TrafficDataResponse(BaseModel):
    """Traffic data record returned from Firestore."""
    id: str
    location_name: str
    latitude: float
    longitude: float
    congestion_level: CongestionLevel
    vehicle_count: int = 0
    average_speed_kmh: float = 0.0
    hour: int = 0
    day_of_week: str = ""
    date: Optional[str] = None
    source: str = "manual"
    timestamp: Optional[datetime] = None


class TrafficBulkUpload(BaseModel):
    """Upload multiple traffic records at once (Excel import)."""
    records: list[TrafficDataUpload]


class TrafficRealtimeUpdate(BaseModel):
    """Live traffic update from a sensor or user device."""
    location_name: str = Field(..., min_length=1)
    latitude: float = Field(..., ge=-90, le=90)
    longitude: float = Field(..., ge=-180, le=180)
    congestion_level: CongestionLevel = CongestionLevel.LOW
    vehicle_count: int = Field(default=0, ge=0)
    average_speed_kmh: float = Field(default=30.0, ge=0)


class RouteRequest(BaseModel):
    """Request for Google Maps directions with traffic info."""
    origin: str = Field(..., description="Origin place name or lat,lng")
    destination: str = Field(..., description="Destination place name or lat,lng")


class GoogleRouteResponse(BaseModel):
    """A single route from Google Maps Directions API."""
    summary: str
    distance_km: float
    duration_minutes: float
    duration_in_traffic_minutes: Optional[float] = None
    # Severity of current traffic vs free-flow: "green" | "yellow" | "red".
    # Defaults to "green" when duration_in_traffic is not available (e.g. OSRM fallback).
    traffic_color: str = "green"
    polyline: str = ""
    steps: list[dict] = []
    warnings: list[str] = []


class DirectionsResponse(BaseModel):
    """Full response from the /route endpoint."""
    origin: str
    destination: str
    best_route: Optional[GoogleRouteResponse] = None
    alternative_routes: list[GoogleRouteResponse] = []
    traffic_recommendation: str = ""


class MLPredictionResponse(BaseModel):
    """ML-based traffic prediction result."""
    location: str
    predicted_congestion: str
    predicted_speed: float
    confidence: float
    hour: int
    day_of_week: str
    factors: list[str] = []


# --- App Ratings ---

# --- Incidents ---

class IncidentCreate(BaseModel):
    incident_type: str = Field(..., description="accident / road_block / flood / construction")
    description: str = Field(default="", max_length=500)
    latitude: float = Field(..., ge=-90, le=90)
    longitude: float = Field(..., ge=-180, le=180)
    location_name: str = Field(default="")
    severity: str = Field(default="medium", description="low / medium / high")
    reported_by: str = Field(default="anonymous")


class IncidentResponse(BaseModel):
    id: str
    incident_type: str
    description: str = ""
    latitude: float
    longitude: float
    location_name: str = ""
    severity: str = "medium"
    reported_by: str = "anonymous"
    is_active: bool = True
    timestamp: Optional[datetime] = None


# --- Nepal Locations ---

class NepalLocation(BaseModel):
    id: Optional[str] = None
    location_name: str
    district: str
    latitude: float
    longitude: float
    road_name: str = ""
    is_hotspot: bool = True


# --- Route Suggestions ---

class RouteSuggestion(BaseModel):
    id: Optional[str] = None
    origin: str
    destination: str
    primary_route: dict = {}
    alternative_routes: list[dict] = []
    estimated_time_minutes: float = 0
    distance_km: float = 0
    traffic_level: str = "low"
    timestamp: Optional[datetime] = None


class RatingSubmit(BaseModel):
    """Submit a rating for the app."""
    stars: int = Field(..., ge=1, le=5, description="Rating from 1 to 5 stars")
    feedback: str = Field(default="", max_length=1000, description="Optional feedback text")


class RatingResponse(BaseModel):
    """A single user's rating record."""
    uid: str
    stars: int
    feedback: str = ""
    app_version: str = ""
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None


class RatingSummary(BaseModel):
    """Aggregated rating summary across all users."""
    total_ratings: int
    average_stars: float
    star_distribution: dict[str, int]  # {"1": count, "2": count, ...}
    ratings: list[RatingResponse] = []
