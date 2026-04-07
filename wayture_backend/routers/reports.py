from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, Query

from models.schemas import ReportCreateRequest, ReportResponse, NearbyReportsRequest
from routers.auth import get_current_uid
from services.firebase_service import firebase_service

router = APIRouter()


@router.post("/", response_model=ReportResponse)
async def create_report(req: ReportCreateRequest, uid: str = Depends(get_current_uid)):
    """Create a new community traffic report."""
    report_data = {
        "latitude": req.latitude,
        "longitude": req.longitude,
        "report_type": req.report_type.value,
        "description": req.description,
    }
    report_id = await firebase_service.create_report(uid, report_data)

    return ReportResponse(
        id=report_id,
        uid=uid,
        latitude=req.latitude,
        longitude=req.longitude,
        report_type=req.report_type,
        description=req.description,
        created_at=report_data.get("created_at", datetime.now(timezone.utc)),
        upvotes=0,
    )


@router.get("/nearby", response_model=list[ReportResponse])
async def get_nearby_reports(
    latitude: float = Query(..., ge=-90, le=90),
    longitude: float = Query(..., ge=-180, le=180),
    radius_km: float = Query(default=2.0, ge=0.1, le=20.0),
    uid: str = Depends(get_current_uid),
):
    """Get community reports near a location."""
    reports = await firebase_service.get_nearby_reports(latitude, longitude, radius_km)
    return [
        ReportResponse(
            id=r["id"],
            uid=r.get("uid", ""),
            latitude=r["latitude"],
            longitude=r["longitude"],
            report_type=r["report_type"],
            description=r.get("description"),
            created_at=r["created_at"],
            upvotes=r.get("upvotes", 0),
        )
        for r in reports
    ]
