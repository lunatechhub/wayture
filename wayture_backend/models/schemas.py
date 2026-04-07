from pydantic import BaseModel, Field
from typing import Optional
from datetime import datetime
from enum import Enum


# --- Enums ---

class CongestionLevel(str, Enum):
    GREEN = "green"
    YELLOW = "yellow"
    RED = "red"


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
