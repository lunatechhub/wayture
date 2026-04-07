from fastapi import APIRouter, Depends

from models.schemas import NotificationResponse, MarkReadRequest
from routers.auth import get_current_uid
from services.firebase_service import firebase_service

router = APIRouter()


@router.get("/unread", response_model=list[NotificationResponse])
async def get_unread_notifications(uid: str = Depends(get_current_uid)):
    """Get all unread notifications for the current user."""
    notifications = await firebase_service.get_unread_notifications(uid)
    return [
        NotificationResponse(
            id=n["id"],
            uid=n["uid"],
            title=n["title"],
            body=n["body"],
            read=n.get("read", False),
            created_at=n["created_at"],
        )
        for n in notifications
    ]


@router.post("/mark-read")
async def mark_read(req: MarkReadRequest, uid: str = Depends(get_current_uid)):
    """Mark notifications as read."""
    await firebase_service.mark_notifications_read(req.notification_ids)
    return {"message": f"Marked {len(req.notification_ids)} notifications as read"}
