from __future__ import annotations

from fastapi import APIRouter, Depends
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth import require_roles
from app.core.response import success
from app.database import get_db
from app.models import StudentProfile
from app.services.assessment_service import refresh_profile

router = APIRouter()


@router.get("/profile/me", tags=["profile"])
async def get_profile(db: AsyncSession = Depends(get_db), user=Depends(require_roles("STUDENT"))):
    profile = await db.scalar(select(StudentProfile).where(StudentProfile.user_id == user.id))
    if not profile:
        profile = await refresh_profile(db, user.id)
        await db.commit()
    return success({
        "user_id": profile.user_id,
        "skill_scores": profile.skill_scores or {},
        "radar_data": profile.radar_data or {},
        "self_tags": profile.self_tags or [],
        "match_version": profile.match_version,
    })


@router.post("/profile/refresh", tags=["profile"])
async def refresh_student_profile(db: AsyncSession = Depends(get_db), user=Depends(require_roles("STUDENT"))):
    profile = await refresh_profile(db, user.id)
    await db.commit()
    return success({
        "user_id": profile.user_id,
        "skill_scores": profile.skill_scores or {},
        "radar_data": profile.radar_data or {},
        "match_version": profile.match_version,
    })
