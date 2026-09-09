"""Job/employment logic: CRUD, application flow, favorite, profile refresh, recommendations.

All DB-mutating functions accept an AsyncSession for dependency injection;
pure helpers have no DB dependency and are directly unit-testable.
"""
from __future__ import annotations

from datetime import datetime

from fastapi import HTTPException
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models import (
    Course as CourseModel, CourseSkillTag, JobApplication, JobFavorite,
    JobPosting, StudentProfile, User,
)
from app.schemas import JobApplicationRead
from app.services import calc_match
from app.services.resume_service import get_default_resume


_DEMO_PROFILE = {"Python": 85, "FastAPI": 72, "MySQL": 65, "SQL": 60, "数据分析": 45}


def job_skills(job: JobPosting) -> list[str]:
    return [skill.strip() for skill in job.required_skills.split(",") if skill.strip()]


def job_out(
    job: JobPosting, profile: dict[str, float], *,
    favorite: bool = False, application_status: str | None = None, gap_courses: list[str] | None = None,
) -> dict:
    required = job_skills(job)
    weights = job.skill_weights or {}
    return {
        "id": job.id,
        "title": job.title,
        "company": job.company,
        "description": job.description,
        "required_skills": required,
        **calc_match(profile, required, weights),
        "is_favorite": favorite,
        "application_status": application_status,
        "gap_courses": gap_courses or [],
    }


async def load_student_profile(db: AsyncSession, user: User | None) -> dict[str, float]:
    if user is None:
        return _DEMO_PROFILE
    profile = await db.scalar(select(StudentProfile).where(StudentProfile.user_id == user.id))
    if not profile or not profile.skill_scores:
        return _DEMO_PROFILE
    return profile.skill_scores


async def gap_courses(db: AsyncSession, gap_tags: list[str]) -> list[str]:
    if not gap_tags:
        return []
    rows = (
        await db.execute(
            select(CourseModel.title)
            .join(CourseSkillTag, CourseSkillTag.course_id == CourseModel.id)
            .where(CourseSkillTag.tag_name.in_(gap_tags))
            .distinct()
        )
    ).scalars().all()
    return list(rows)


def validate_job_active(job: JobPosting | None) -> JobPosting:
    if not job or not job.is_active or job.review_status != 1:
        raise HTTPException(404, "岗位不存在或已下线")
    return job


async def list_recommendations(db: AsyncSession, user: User | None) -> list[dict]:
    profile = await load_student_profile(db, user)
    jobs = (
        await db.execute(
            select(JobPosting).where(JobPosting.is_active.is_(True), JobPosting.review_status == 1)
        )
    ).scalars().all()
    return [job_out(job, profile) for job in jobs]


async def apply_job_flow(db: AsyncSession, user_id: int, job_id: int) -> dict:
    job = validate_job_active(await db.get(JobPosting, job_id))
    application = (
        await db.execute(
            select(JobApplication).where(JobApplication.user_id == user_id, JobApplication.job_id == job_id)
        )
    ).scalar_one_or_none()
    if not application:
        resume = await get_default_resume(db, user_id)
        application = JobApplication(
            user_id=user_id, job_id=job_id, resume_snapshot=(resume.content if resume else {}),
        )
        db.add(application)
        try:
            await db.commit()
        except IntegrityError:
            await db.rollback()
            application = (
                await db.execute(
                    select(JobApplication).where(JobApplication.user_id == user_id, JobApplication.job_id == job_id)
                )
            ).scalar_one()
    await db.refresh(application)
    return JobApplicationRead.model_validate(application).model_dump()


async def list_applications(db: AsyncSession, user_id: int) -> list[dict]:
    rows = (await db.execute(select(JobApplication).where(JobApplication.user_id == user_id))).scalars().all()
    return [JobApplicationRead.model_validate(row).model_dump() for row in rows]


async def update_application_status_flow(
    db: AsyncSession, application_id: int, status: str, reject_reason: str | None,
) -> dict:
    valid = {"VIEWED", "INTERVIEW", "OFFER", "REJECTED"}
    if status.upper() not in valid:
        raise HTTPException(422, "status 必须是 VIEWED/INTERVIEW/OFFER/REJECTED")
    application = await db.get(JobApplication, application_id)
    if not application:
        raise HTTPException(404, "投递不存在")
    application.status = status.upper()
    application.reject_reason = reject_reason
    application.status_time = datetime.utcnow()
    await db.commit()
    await db.refresh(application)
    return {"id": application.id, "status": application.status, "status_time": application.status_time}


async def favorite_job_flow(db: AsyncSession, user_id: int, job_id: int) -> dict:
    validate_job_active(await db.get(JobPosting, job_id))
    favorite = (
        await db.execute(select(JobFavorite).where(JobFavorite.user_id == user_id, JobFavorite.job_id == job_id))
    ).scalar_one_or_none()
    if not favorite:
        db.add(JobFavorite(user_id=user_id, job_id=job_id))
        try:
            await db.commit()
        except IntegrityError:
            await db.rollback()
    return {"job_id": job_id, "favorited": True}


async def unfavorite_job_flow(db: AsyncSession, user_id: int, job_id: int) -> dict:
    favorite = (
        await db.execute(select(JobFavorite).where(JobFavorite.user_id == user_id, JobFavorite.job_id == job_id))
    ).scalar_one_or_none()
    if favorite:
        await db.delete(favorite)
        await db.commit()
    return {"job_id": job_id, "favorited": False}


async def list_favorites(db: AsyncSession, user: User) -> list[dict]:
    favorites = (
        await db.execute(
            select(JobFavorite).options(selectinload(JobFavorite.job)).where(JobFavorite.user_id == user.id)
        )
    ).scalars().all()
    profile = await load_student_profile(db, user)
    return [job_out(favorite.job, profile, favorite=True) for favorite in favorites]


async def job_detail_flow(db: AsyncSession, user_id: int, job_id: int) -> dict:
    job = validate_job_active(await db.get(JobPosting, job_id))
    favorite = (
        await db.execute(
            select(JobFavorite).where(JobFavorite.user_id == user_id, JobFavorite.job_id == job_id)
        )
    ).scalar_one_or_none()
    application = (
        await db.execute(
            select(JobApplication).where(JobApplication.user_id == user_id, JobApplication.job_id == job_id)
        )
    ).scalar_one_or_none()
    user = await db.get(User, user_id)
    profile = await load_student_profile(db, user)
    out = job_out(
        job, profile,
        favorite=favorite is not None,
        application_status=application.status if application else None,
    )
    out["gap_courses"] = await gap_courses(db, out["gap_tags"])
    return out
