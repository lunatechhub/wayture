from fastapi import APIRouter, HTTPException, Depends, Header

from models.schemas import UserRegisterRequest, UserResponse, LoginRequest, AuthResponse
from services.firebase_service import firebase_service

router = APIRouter()


async def get_current_uid(authorization: str = Header(...)) -> str:
    """Extract and verify Firebase token from Authorization header."""
    if not firebase_service.is_initialized:
        raise HTTPException(status_code=503, detail="Firebase is not initialized")

    token = authorization.replace("Bearer ", "")
    try:
        decoded = firebase_service.verify_firebase_token(token)
        return decoded["uid"]
    except Exception as e:
        raise HTTPException(status_code=401, detail=f"Invalid token: {e}")


@router.post("/register", response_model=AuthResponse)
async def register(req: UserRegisterRequest):
    """Register a new user after Firebase auth."""
    if not firebase_service.is_initialized:
        raise HTTPException(status_code=503, detail="Firebase is not initialized")

    try:
        decoded = firebase_service.verify_firebase_token(req.firebase_token)
    except Exception as e:
        raise HTTPException(status_code=401, detail=f"Invalid Firebase token: {e}")

    uid = decoded["uid"]
    existing = await firebase_service.get_user(uid)
    if existing:
        raise HTTPException(status_code=409, detail="User already registered")

    user_data = {
        "name": req.name,
        "email": req.email,
        "phone": req.phone,
    }
    await firebase_service.create_user(uid, user_data)

    return AuthResponse(uid=uid, name=req.name, email=req.email, message="Registration successful")


@router.post("/login", response_model=AuthResponse)
async def login(req: LoginRequest):
    """Verify Firebase token and return user data."""
    if not firebase_service.is_initialized:
        raise HTTPException(status_code=503, detail="Firebase is not initialized")

    try:
        decoded = firebase_service.verify_firebase_token(req.firebase_token)
    except Exception as e:
        raise HTTPException(status_code=401, detail=f"Invalid Firebase token: {e}")

    uid = decoded["uid"]
    user = await firebase_service.get_user(uid)
    if not user:
        raise HTTPException(status_code=404, detail="User not registered. Please register first.")

    return AuthResponse(uid=uid, name=user["name"], email=user["email"], message="Login successful")
