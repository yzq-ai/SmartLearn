from __future__ import annotations

from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.auth import current_user, get_optional_user, require_roles
from app.core.response import success
from app.database import get_db
from app.models import (
    CareerEvent as CareerEventModel, CareerEventSignup,
    Company, Course as CourseModel, CourseSkillTag, JobApplication, JobFavorite,
    JobPosting, Resume, SensitiveWord, StudentProfile,
)
from app.schemas import CareerEventCreate, CompanyCreate, JobApplicationRead, JobCreate, JobStatusUpdate
from app.services import calc_match
from app.services.match_engine import normalize_profile
from app.services.sensitive import scan_sensitive

router = APIRouter()

_DEMO_PROFILE = {"Python": 85, "FastAPI": 72, "MySQL": 65, "SQL": 60, "数据分析": 45}


async def _sensitive_words(db: AsyncSession) -> list[str]:
    rows = (await db.execute(select(SensitiveWord.word))).scalars().all()
    return list(rows)


def _job_skills(job: JobPosting) -> list[str]:
    return [skill.strip() for skill in job.required_skills.split(",") if skill.strip()]


async def _load_student_profile(db: AsyncSession, user: User | None) -> dict[str, float]:
    if user is None:
        return _DEMO_PROFILE
    profile = await db.scalar(select(StudentProfile).where(StudentProfile.user_id == user.id))
    if not profile or not profile.skill_scores:
        return _DEMO_PROFILE
    return profile.skill_scores


async def _gap_courses(db: AsyncSession, gap_tags: list[str]) -> list[str]:
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


def _job_out(job: JobPosting, profile: dict[str, float], *, favorite=False, application_status=None, gap_courses=None) -> dict:
    required = _job_skills(job)
    weights = job.skill_weights or {}
    match = calc_match(profile, required, weights)
    # 附带本岗位相关技能的真实掌握分（归一命名空间，供端侧雷达真值渲染）
    norm = normalize_profile(profile)
    skill_scores = {t: round(float(norm.get(t, 0.0)), 1) for t in match["matched_tags"] + match["gap_tags"]}
    return {
        "id": job.id,
        "title": job.title,
        "company": job.company,
        "description": job.description,
        "required_skills": required,
        **match,
        "skill_scores": skill_scores,
        "is_favorite": favorite,
        "application_status": application_status,
        "gap_courses": gap_courses or [],
    }


@router.post("/jobs", tags=["jobs"])
async def create_job(payload: JobCreate, db: AsyncSession = Depends(get_db), user=Depends(require_roles("TEACHER", "ADMIN"))):
    words = await _sensitive_words(db)
    hits = scan_sensitive(f"{payload.title}\n{payload.description}", words)
    job = JobPosting(
        title=payload.title,
        company=payload.company,
        description=payload.description,
        required_skills=",".join(payload.required_skills),
        city=payload.city,
        job_type=payload.job_type,
        review_status=0,
        created_by=user.id,
    )
    db.add(job)
    await db.commit()
    await db.refresh(job)
    return success({
        "id": job.id,
        "title": job.title,
        "company": job.company,
        "review_status": job.review_status,
        "sensitive_hits": hits,
    })


@router.post("/companies", tags=["jobs"])
async def create_company(payload: CompanyCreate, db: AsyncSession = Depends(get_db), user=Depends(require_roles("TEACHER", "ADMIN"))):
    words = await _sensitive_words(db)
    hits = scan_sensitive(f"{payload.name}\n{payload.intro or ''}", words)
    company = Company(
        name=payload.name,
        industry=payload.industry,
        scale=payload.scale,
        intro=payload.intro,
        verify_status=0,
        created_by=user.id,
    )
    db.add(company)
    await db.commit()
    await db.refresh(company)
    return success({
        "id": company.id,
        "name": company.name,
        "verify_status": company.verify_status,
        "sensitive_hits": hits,
    })


@router.get("/companies", tags=["jobs"])
async def list_companies(db: AsyncSession = Depends(get_db), user=Depends(require_roles("ADMIN"))):
    rows = (await db.execute(select(Company).order_by(Company.id))).scalars().all()
    return success([
        {"id": c.id, "name": c.name, "industry": c.industry, "scale": c.scale,
         "intro": c.intro, "verify_status": c.verify_status}
        for c in rows
    ])


@router.get("/jobs/recommendations", tags=["jobs"])
async def recommendations(db: AsyncSession = Depends(get_db), user=Depends(get_optional_user)):
    profile = await _load_student_profile(db, user)
    jobs = (
        await db.execute(
            select(JobPosting).where(JobPosting.is_active.is_(True), JobPosting.review_status == 1)
        )
    ).scalars().all()
    return success([_job_out(job, profile) for job in jobs])


@router.post("/jobs/{job_id}/applications", tags=["jobs"])
@router.post("/jobs/{job_id}/apply", tags=["jobs"], include_in_schema=False)
async def apply_job(job_id: int, db: AsyncSession = Depends(get_db), user=Depends(require_roles("STUDENT"))):
    job = await db.get(JobPosting, job_id)
    if not job or not job.is_active or job.review_status != 1:
        raise HTTPException(404, "岗位不存在或已下线")
    application = (
        await db.execute(
            select(JobApplication).where(JobApplication.user_id == user.id, JobApplication.job_id == job_id)
        )
    ).scalar_one_or_none()
    if not application:
        resume = (
            await db.execute(
                select(Resume).where(Resume.user_id == user.id, Resume.is_default == 1).order_by(Resume.id.desc())
            )
        ).scalars().first()
        application = JobApplication(user_id=user.id, job_id=job_id, resume_snapshot=(resume.content if resume else {}))
        db.add(application)
        try:
            await db.commit()
        except IntegrityError:
            await db.rollback()
            application = (
                await db.execute(
                    select(JobApplication).where(JobApplication.user_id == user.id, JobApplication.job_id == job_id)
                )
            ).scalar_one()
    await db.refresh(application)
    return success(JobApplicationRead.model_validate(application).model_dump())


@router.get("/jobs/applications", tags=["jobs"])
async def list_applications(db: AsyncSession = Depends(get_db), user=Depends(require_roles("STUDENT"))):
    rows = (await db.execute(select(JobApplication).where(JobApplication.user_id == user.id))).scalars().all()
    return success([JobApplicationRead.model_validate(row).model_dump() for row in rows])


@router.put("/applications/{application_id}/status", tags=["jobs"])
async def update_application_status(
    application_id: int, payload: JobStatusUpdate, db: AsyncSession = Depends(get_db), user=Depends(require_roles("TEACHER", "ADMIN")),
):
    valid = {"VIEWED", "INTERVIEW", "OFFER", "REJECTED"}
    if payload.status.upper() not in valid:
        raise HTTPException(422, "status 必须是 VIEWED/INTERVIEW/OFFER/REJECTED")
    application = await db.get(JobApplication, application_id)
    if not application:
        raise HTTPException(404, "投递不存在")
    application.status = payload.status.upper()
    application.reject_reason = payload.reject_reason
    application.status_time = datetime.utcnow()
    await db.commit()
    await db.refresh(application)
    return success({"id": application.id, "status": application.status, "status_time": application.status_time})


@router.put("/jobs/{job_id}/favorite", tags=["jobs"])
async def favorite_job(job_id: int, db: AsyncSession = Depends(get_db), user=Depends(require_roles("STUDENT"))):
    job = await db.get(JobPosting, job_id)
    if not job or not job.is_active or job.review_status != 1:
        raise HTTPException(404, "岗位不存在或已下线")
    favorite = (
        await db.execute(select(JobFavorite).where(JobFavorite.user_id == user.id, JobFavorite.job_id == job_id))
    ).scalar_one_or_none()
    if not favorite:
        db.add(JobFavorite(user_id=user.id, job_id=job_id))
        try:
            await db.commit()
        except IntegrityError:
            await db.rollback()
    return success({"job_id": job_id, "favorited": True})


@router.delete("/jobs/{job_id}/favorite", tags=["jobs"])
async def unfavorite_job(job_id: int, db: AsyncSession = Depends(get_db), user=Depends(require_roles("STUDENT"))):
    favorite = (
        await db.execute(select(JobFavorite).where(JobFavorite.user_id == user.id, JobFavorite.job_id == job_id))
    ).scalar_one_or_none()
    if favorite:
        await db.delete(favorite)
        await db.commit()
    return success({"job_id": job_id, "favorited": False})


@router.get("/jobs/favorites", tags=["jobs"])
async def list_favorites(db: AsyncSession = Depends(get_db), user=Depends(require_roles("STUDENT"))):
    favorites = (
        await db.execute(
            select(JobFavorite).options(selectinload(JobFavorite.job)).where(JobFavorite.user_id == user.id)
        )
    ).scalars().all()
    profile = await _load_student_profile(db, user)
    return success([_job_out(favorite.job, profile, favorite=True) for favorite in favorites])


@router.get("/jobs/{job_id}", tags=["jobs"])
async def job_detail(job_id: int, db: AsyncSession = Depends(get_db), user=Depends(current_user)):
    job = await db.get(JobPosting, job_id)
    if not job or not job.is_active or job.review_status != 1:
        raise HTTPException(404, "岗位不存在或已下线")
    favorite = (
        await db.execute(
            select(JobFavorite).where(JobFavorite.user_id == user.id, JobFavorite.job_id == job_id)
        )
    ).scalar_one_or_none()
    application = (
        await db.execute(
            select(JobApplication).where(JobApplication.user_id == user.id, JobApplication.job_id == job_id)
        )
    ).scalar_one_or_none()
    profile = await _load_student_profile(db, user)
    out = _job_out(job, profile, favorite=favorite is not None, application_status=application.status if application else None)
    out["gap_courses"] = await _gap_courses(db, out["gap_tags"])
    return success(out)


# ═══════════════ 招聘活动 / 实习实践 ═══════════════


@router.get("/career-events", tags=["jobs"])
async def list_career_events(
    event_type: str | None = None,
    db: AsyncSession = Depends(get_db),
    user=Depends(current_user),
):
    """招聘活动列表（宣讲会/双选会/实习实践）。event_type 可选过滤。"""
    statement = select(CareerEventModel).where(CareerEventModel.review_status == 1)
    if event_type is not None:
        statement = statement.where(CareerEventModel.event_type == event_type)
    rows = (await db.execute(statement.order_by(CareerEventModel.start_time.desc()))).scalars().all()
    if not rows:
        return success([])
    # 主办企业名
    company_ids = [e.company_id for e in rows if e.company_id is not None]
    company_names: dict[int, str] = {}
    if company_ids:
        comps = (await db.execute(select(Company).where(Company.id.in_(company_ids)))).scalars().all()
        company_names = {c.id: c.name for c in comps}
    # 报名计数与本人报名状态
    event_ids = [e.id for e in rows]
    signup_rows = (await db.execute(
        select(CareerEventSignup).where(CareerEventSignup.event_id.in_(event_ids))
    )).scalars().all()
    signup_count: dict[int, int] = {}
    for s in signup_rows:
        signup_count[s.event_id] = signup_count.get(s.event_id, 0) + 1
    my_set: set[int] = set(s.event_id for s in signup_rows if s.user_id == user.id)
    now = datetime.utcnow()
    return success([
        {
            "id": e.id,
            "title": e.title,
            "event_type": e.event_type or "TALK",
            "company": company_names.get(e.company_id, ""),
            "description": e.description,
            "location": e.location,
            "start_time": e.start_time,
            "end_time": e.end_time,
            "signup_count": signup_count.get(e.id, 0),
            "signed_up": e.id in my_set,
            "is_ended": now > e.end_time,
        }
        for e in rows
    ])


@router.post("/career-events", tags=["jobs"])
async def create_career_event(
    payload: CareerEventCreate,
    db: AsyncSession = Depends(get_db),
    user=Depends(require_roles("TEACHER", "ADMIN")),
):
    """教师/管理员发布招聘活动（宣讲会/双选会/实习实践），先审后发。"""
    words = await _sensitive_words(db)
    hits = scan_sensitive(f"{payload.title}\n{payload.description or ''}", words)
    if hits:
        raise HTTPException(422, f"内容包含敏感词：{'、'.join(hits)}")
    event = CareerEventModel(
        title=payload.title,
        event_type=payload.event_type,
        company_id=payload.company_id,
        description=payload.description,
        location=payload.location,
        start_time=payload.start_time,
        end_time=payload.end_time,
        review_status=1,  # 教师发布即过审；管理员可在审核台复核下线
    )
    db.add(event)
    await db.commit()
    await db.refresh(event)
    return success({"id": event.id, "title": event.title, "event_type": event.event_type, "message": "活动已发布"})


@router.post("/career-events/{event_id}/signup", tags=["jobs"])
async def signup_career_event(
    event_id: int,
    db: AsyncSession = Depends(get_db),
    user=Depends(require_roles("STUDENT")),
):
    """学生报名招聘活动（幂等：重复报名返回已报名状态）。"""
    event = await db.get(CareerEventModel, event_id)
    if not event or event.review_status != 1:
        raise HTTPException(404, "活动不存在或已下线")
    if datetime.utcnow() > event.end_time:
        raise HTTPException(409, "活动已结束，无法报名")
    existing = (
        await db.execute(
            select(CareerEventSignup).where(
                CareerEventSignup.event_id == event_id, CareerEventSignup.user_id == user.id
            )
        )
    ).scalar_one_or_none()
    if existing is not None:
        return success({"event_id": event_id, "signed_up": True, "first_time": False})
    db.add(CareerEventSignup(event_id=event_id, user_id=user.id))
    await db.commit()
    return success({"event_id": event_id, "signed_up": True, "first_time": True})
