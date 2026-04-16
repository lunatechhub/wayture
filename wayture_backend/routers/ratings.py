"""App rating endpoints.

POST /submit         — submit or update a rating (requires auth)
GET  /my-rating      — fetch the current user's rating (requires auth)
GET  /all            — fetch all ratings
GET  /summary        — aggregated rating summary (avg, distribution)
"""

from fastapi import APIRouter, HTTPException, Depends

from models.schemas import RatingSubmit, RatingResponse, RatingSummary
from routers.auth import get_current_uid
from services.firebase_service import firebase_service

router = APIRouter()


@router.post("/submit", response_model=dict)
async def submit_rating(data: RatingSubmit, uid: str = Depends(get_current_uid)):
    """Submit or update the current user's app rating.

    Stores in the appRatings/{uid} document so each user has exactly one rating.
    """
    if not firebase_service.is_initialized:
        raise HTTPException(status_code=503, detail="Firebase not initialized")

    record = {
        "stars": data.stars,
        "feedback": data.feedback,
        "app_version": "1.0.0",
    }
    await firebase_service.store_rating(uid, record)
    return {"status": "ok", "message": f"Rating of {data.stars} stars saved"}


@router.get("/my-rating", response_model=RatingResponse | None)
async def get_my_rating(uid: str = Depends(get_current_uid)):
    """Fetch the current signed-in user's rating."""
    if not firebase_service.is_initialized:
        raise HTTPException(status_code=503, detail="Firebase not initialized")

    doc = await firebase_service.get_rating(uid)
    if not doc:
        return None

    return _doc_to_rating(doc)


@router.get("/all", response_model=list[RatingResponse])
async def get_all_ratings():
    """Fetch all user ratings (public — no auth required)."""
    if not firebase_service.is_initialized:
        raise HTTPException(status_code=503, detail="Firebase not initialized")

    docs = await firebase_service.get_all_ratings()
    return [_doc_to_rating(d) for d in docs]


@router.get("/summary", response_model=RatingSummary)
async def get_rating_summary():
    """Aggregated rating summary — average stars, distribution, total count."""
    if not firebase_service.is_initialized:
        raise HTTPException(status_code=503, detail="Firebase not initialized")

    docs = await firebase_service.get_all_ratings()

    if not docs:
        return RatingSummary(
            total_ratings=0,
            average_stars=0.0,
            star_distribution={"1": 0, "2": 0, "3": 0, "4": 0, "5": 0},
            ratings=[],
        )

    stars_list = [d.get("stars", 0) for d in docs]
    avg = sum(stars_list) / len(stars_list) if stars_list else 0.0

    distribution = {"1": 0, "2": 0, "3": 0, "4": 0, "5": 0}
    for s in stars_list:
        key = str(min(max(s, 1), 5))
        distribution[key] = distribution.get(key, 0) + 1

    return RatingSummary(
        total_ratings=len(docs),
        average_stars=round(avg, 1),
        star_distribution=distribution,
        ratings=[_doc_to_rating(d) for d in docs],
    )


def _doc_to_rating(doc: dict) -> RatingResponse:
    return RatingResponse(
        uid=doc.get("uid", doc.get("id", "")),
        stars=doc.get("stars", 0),
        feedback=doc.get("feedback", ""),
        app_version=doc.get("app_version", ""),
        created_at=doc.get("created_at"),
        updated_at=doc.get("updated_at"),
    )
