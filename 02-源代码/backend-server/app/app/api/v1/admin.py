from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth import current_user, hash_password, require_roles
from app.core.audit import write_audit
from app.core.config import settings
from app.core.response import success
from app.database import get_db
from app.models import (
    Company, DiscussionPost, DiscussionReply, JobPosting,
    SensitiveWord, SysAuditLog, SysConfig, User, JobSkillTag,
)
from app.schemas import (
    ConfigUpsert,
    ReviewDecision,
    SensitiveWordCreate,
    SkillTagCreate,
    UserImportRequest,
    UserPasswordReset,
    UserStatusUpdate,
)

router = APIRouter()


async def _sensitive_words(db: AsyncSession) -> list[str]:
    rows = (await db.execute(select(SensitiveWord.word))).scalars().all()
    return list(rows)


@router.get("/admin/reviews/pending", tags=["admin"])
async def pending_reviews(db: AsyncSession = Depends(get_db), user=Depends(require_roles("ADMIN"))):
    jobs = (
        await db.execute(select(JobPosting).where(JobPosting.review_status == 0))
    ).scalars().all()
    companies = (
        await db.execute(select(Company).where(Company.verify_status == 0))
    ).scalars().all()
    posts = (
        await db.execute(select(DiscussionPost).where(DiscussionPost.review_status == 0))
    ).scalars().all()
    replies = (
        await db.execute(select(DiscussionReply).where(DiscussionReply.review_status == 0))
    ).scalars().all()
    return success({
        "jobs": [
            {"id": j.id, "title": j.title, "company": j.company, "description": j.description,
             "created_by": j.created_by, "created_at": j.created_at}
            for j in jobs
        ],
        "companies": [
            {"id": c.id, "name": c.name, "industry": c.industry, "intro": c.intro,
             "created_by": c.created_by}
            for c in companies
        ],
        "posts": [
            {"id": p.id, "course_id": p.course_id, "title": p.title, "content": p.content,
             "user_id": p.user_id}
            for p in posts
        ],
        "replies": [
            {"id": r.id, "post_id": r.post_id, "content": r.content, "user_id": r.user_id}
            for r in replies
        ],
    })


@router.post("/admin/reviews", tags=["admin"])
async def decide_review(payload: ReviewDecision, db: AsyncSession = Depends(get_db), user=Depends(require_roles("ADMIN"))):
    action = payload.action.upper()
    if action not in ("APPROVE", "REJECT"):
        raise HTTPException(422, "action 必须是 APPROVE 或 REJECT")
    if action == "REJECT" and not (payload.reason or "").strip():
        raise HTTPException(422, "驳回必须填写理由")

    if payload.target_type.upper() == "JOB":
        job = await db.get(JobPosting, payload.target_id)
        if not job:
            raise HTTPException(404, "岗位不存在")
        job.review_status = 1 if action == "APPROVE" else 2
        if action == "REJECT":
            job.reject_reason = payload.reason
        await db.commit()
        return success({"target_type": "JOB", "target_id": job.id, "review_status": job.review_status})

    if payload.target_type.upper() == "COMPANY":
        company = await db.get(Company, payload.target_id)
        if not company:
            raise HTTPException(404, "企业不存在")
        company.verify_status = 1 if action == "APPROVE" else 2
        if action == "REJECT":
            company.reject_reason = payload.reason
        await db.commit()
        return success({"target_type": "COMPANY", "target_id": company.id, "verify_status": company.verify_status})

    if payload.target_type.upper() == "POST":
        post = await db.get(DiscussionPost, payload.target_id)
        if not post:
            raise HTTPException(404, "帖子不存在")
        post.review_status = 1 if action == "APPROVE" else 2
        if action == "REJECT":
            post.status = 0
        await db.commit()
        return success({"target_type": "POST", "target_id": post.id, "review_status": post.review_status})

    if payload.target_type.upper() == "REPLY":
        reply = await db.get(DiscussionReply, payload.target_id)
        if not reply:
            raise HTTPException(404, "回复不存在")
        reply.review_status = 1 if action == "APPROVE" else 2
        await db.commit()
        return success({"target_type": "REPLY", "target_id": reply.id, "review_status": reply.review_status})

    raise HTTPException(422, "target_type 必须是 JOB / COMPANY / POST / REPLY")


@router.get("/admin/stats/dashboard", tags=["admin"])
async def admin_dashboard(db: AsyncSession = Depends(get_db), user=Depends(require_roles("ADMIN"))):
    from app.models import Exam, JobApplication, Course

    users = len((await db.execute(select(User.id))).scalars().all())
    courses = len((await db.execute(select(Course.id))).scalars().all())
    exams = len((await db.execute(select(Exam.id))).scalars().all())
    jobs = len((await db.execute(select(JobPosting.id))).scalars().all())
    pending_jobs = len((await db.execute(select(JobPosting.id).where(JobPosting.review_status == 0))).scalars().all())
    applications = len((await db.execute(select(JobApplication.id))).scalars().all())
    return success({
        "users": users,
        "courses": courses,
        "exams": exams,
        "jobs": jobs,
        "pending_jobs": pending_jobs,
        "applications": applications,
    })


@router.get("/admin/stats/trend", tags=["admin"])
async def admin_dau_trend(db: AsyncSession = Depends(get_db), user=Depends(require_roles("ADMIN"))):
    """近 7 天活跃趋势：以 sys_login_log 按日聚合 distinct user 数（无日志日补 0）。"""
    from datetime import date, timedelta

    from sqlalchemy import func

    from app.models import SysLoginLog

    today = date.today()
    days = [(today - timedelta(days=i)) for i in range(6, -1, -1)]
    rows = (
        await db.execute(
            select(func.date(SysLoginLog.created_at), func.count(func.distinct(SysLoginLog.user_id)))
            .where(SysLoginLog.created_at >= today - timedelta(days=6))
            .group_by(func.date(SysLoginLog.created_at))
        )
    ).all()
    per_day = {str(d): c for d, c in rows}
    labels = [d.strftime("%m-%d") for d in days]
    values = [int(per_day.get(d.isoformat(), 0)) for d in days]
    return success({"labels": labels, "values": values, "metric": "dau"})


@router.get("/admin/stats/funnel", tags=["admin"])
async def admin_apply_funnel(db: AsyncSession = Depends(get_db), user=Depends(require_roles("ADMIN"))):
    """投递漏斗：收藏 → 投递 → 被查看 → 面试 → Offer。"""
    from app.models import JobApplication

    favorites = 0
    try:
        from app.models import JobFavorite

        favorites = len((await db.execute(select(JobFavorite.id))).scalars().all())
    except ImportError:
        favorites = 0
    apps = (await db.execute(select(JobApplication))).scalars().all()
    by_status: dict[str, int] = {}
    for a in apps:
        by_status[a.status] = by_status.get(a.status, 0) + 1
    viewed = by_status.get("VIEWED", 0) + by_status.get("INTERVIEW", 0) + by_status.get("OFFER", 0) + by_status.get("REJECTED", 0)
    interview = by_status.get("INTERVIEW", 0) + by_status.get("OFFER", 0)
    offer = by_status.get("OFFER", 0)
    return success({
        "labels": ["收藏", "投递", "被查看", "面试", "Offer"],
        "values": [max(favorites, len(apps)), len(apps), viewed, interview, offer],
    })


@router.get("/admin/integrations", tags=["admin"])
async def integrations_status(user=Depends(require_roles("ADMIN"))):
    from app.services.obs import check_obs
    from app.services.push_service import check_push
    from app.services.vector_store import check_vector

    return success({
        "obs": check_obs(),
        "push": check_push(),
        "vector": check_vector(),
    })


@router.post("/admin/tasks/{task_name}", tags=["admin"])
async def trigger_task(task_name: str, db: AsyncSession = Depends(get_db), user=Depends(require_roles("ADMIN"))):
    from app.tasks.jobs import aggregate_daily_stats, auto_collect_exams, refresh_profile

    if task_name == "aggregate-stats":
        result = aggregate_daily_stats.delay()
    elif task_name == "auto-collect":
        result = auto_collect_exams.delay()
    elif task_name == "refresh-profile":
        result = refresh_profile.delay(user.id)
    else:
        raise HTTPException(404, "未知任务")

    if settings.celery_always_eager:
        return success({"task": task_name, "result": result.result})
    return success({"task": task_name, "task_id": result.id})


@router.get("/admin/sensitive-words", tags=["admin"])
async def list_sensitive_words(db: AsyncSession = Depends(get_db), user=Depends(require_roles("ADMIN"))):
    rows = (await db.execute(select(SensitiveWord).order_by(SensitiveWord.id))).scalars().all()
    return success([{"id": w.id, "word": w.word, "level": w.level} for w in rows])


@router.post("/admin/sensitive-words", tags=["admin"])
async def create_sensitive_word(payload: SensitiveWordCreate, db: AsyncSession = Depends(get_db), user=Depends(require_roles("ADMIN"))):
    exists = (await db.execute(select(SensitiveWord).where(SensitiveWord.word == payload.word))).scalar_one_or_none()
    if exists:
        raise HTTPException(409, "敏感词已存在")
    word = SensitiveWord(word=payload.word, level=payload.level)
    db.add(word)
    await write_audit(db, user.id, "SENSITIVE_WORD_CREATE", "SENSITIVE_WORD", None, {"word": payload.word})
    await db.commit()
    await db.refresh(word)
    return success({"id": word.id, "word": word.word, "level": word.level})


@router.delete("/admin/sensitive-words/{word_id}", tags=["admin"])
async def delete_sensitive_word(word_id: int, db: AsyncSession = Depends(get_db), user=Depends(require_roles("ADMIN"))):
    word = await db.get(SensitiveWord, word_id)
    if not word:
        raise HTTPException(404, "敏感词不存在")
    await db.delete(word)
    await write_audit(db, user.id, "SENSITIVE_WORD_DELETE", "SENSITIVE_WORD", word_id, {"word": word.word})
    await db.commit()
    return success({"id": word_id, "deleted": True})


@router.get("/admin/configs", tags=["admin"])
async def list_configs(db: AsyncSession = Depends(get_db), user=Depends(require_roles("ADMIN"))):
    rows = (await db.execute(select(SysConfig))).scalars().all()
    return success([{"cfg_key": c.cfg_key, "cfg_value": c.cfg_value, "remark": c.remark} for c in rows])


@router.put("/admin/configs", tags=["admin"])
async def upsert_config(payload: ConfigUpsert, db: AsyncSession = Depends(get_db), user=Depends(require_roles("ADMIN"))):
    config = (await db.execute(select(SysConfig).where(SysConfig.cfg_key == payload.cfg_key))).scalar_one_or_none()
    if config:
        config.cfg_value = payload.cfg_value
        config.remark = payload.remark
    else:
        config = SysConfig(cfg_key=payload.cfg_key, cfg_value=payload.cfg_value, remark=payload.remark)
        db.add(config)
    await write_audit(db, user.id, "CONFIG_UPSERT", "SYS_CONFIG", None, {"cfg_key": payload.cfg_key})
    await db.commit()
    return success({"cfg_key": config.cfg_key, "cfg_value": config.cfg_value, "remark": config.remark})


@router.get("/admin/skill-tags", tags=["admin"])
async def list_skill_tags(db: AsyncSession = Depends(get_db), user=Depends(require_roles("ADMIN"))):
    rows = (await db.execute(select(JobSkillTag).order_by(JobSkillTag.id))).scalars().all()
    return success([{"id": t.id, "name": t.name, "category": t.category} for t in rows])


@router.post("/admin/skill-tags", tags=["admin"])
async def create_skill_tag(payload: SkillTagCreate, db: AsyncSession = Depends(get_db), user=Depends(require_roles("ADMIN"))):
    exists = (await db.execute(select(JobSkillTag).where(JobSkillTag.name == payload.name))).scalar_one_or_none()
    if exists:
        raise HTTPException(409, "技能标签已存在")
    tag = JobSkillTag(name=payload.name, category=payload.category)
    db.add(tag)
    await write_audit(db, user.id, "SKILL_TAG_CREATE", "JOB_SKILL_TAG", None, {"name": payload.name})
    await db.commit()
    await db.refresh(tag)
    return success({"id": tag.id, "name": tag.name, "category": tag.category})


@router.delete("/admin/skill-tags/{tag_id}", tags=["admin"])
async def delete_skill_tag(tag_id: int, db: AsyncSession = Depends(get_db), user=Depends(require_roles("ADMIN"))):
    tag = await db.get(JobSkillTag, tag_id)
    if not tag:
        raise HTTPException(404, "技能标签不存在")
    await db.delete(tag)
    await write_audit(db, user.id, "SKILL_TAG_DELETE", "JOB_SKILL_TAG", tag_id, {"name": tag.name})
    await db.commit()
    return success({"id": tag_id, "deleted": True})


@router.get("/admin/users", tags=["admin"])
async def list_users(db: AsyncSession = Depends(get_db), user=Depends(require_roles("ADMIN")), role: str | None = None):
    statement = select(User).order_by(User.id)
    if role:
        statement = statement.where(User.role == role.upper())
    rows = (await db.execute(statement)).scalars().all()
    return success([
        {"id": u.id, "username": u.username, "real_name": u.real_name, "role": u.role, "status": u.status}
        for u in rows
    ])


@router.put("/admin/users/{user_id}/status", tags=["admin"])
async def set_user_status(user_id: int, payload: UserStatusUpdate, db: AsyncSession = Depends(get_db), user=Depends(require_roles("ADMIN"))):
    target = await db.get(User, user_id)
    if not target:
        raise HTTPException(404, "用户不存在")
    target.status = payload.status
    await write_audit(db, user.id, "USER_STATUS", "USER", user_id, {"status": payload.status})
    await db.commit()
    return success({"id": target.id, "status": target.status})


@router.post("/admin/users/{user_id}/reset-password", tags=["admin"])
async def reset_password(user_id: int, payload: UserPasswordReset, db: AsyncSession = Depends(get_db), user=Depends(require_roles("ADMIN"))):
    target = await db.get(User, user_id)
    if not target:
        raise HTTPException(404, "用户不存在")
    target.password_hash = hash_password(payload.new_password)
    await write_audit(db, user.id, "USER_RESET_PASSWORD", "USER", user_id, {})
    await db.commit()
    return success({"id": target.id, "reset": True})


@router.post("/admin/users/import", tags=["admin"])
async def import_users(payload: UserImportRequest, db: AsyncSession = Depends(get_db), user=Depends(require_roles("ADMIN"))):
    success_list: list[str] = []
    failed: list[dict] = []
    for item in payload.users:
        username = item.username.strip()
        if not username:
            failed.append({"username": username, "reason": "账号为空"})
            continue
        exists = (await db.execute(select(User).where(User.username == username))).scalar_one_or_none()
        if exists:
            failed.append({"username": username, "reason": "账号已存在"})
            continue
        if item.role.upper() not in ("STUDENT", "TEACHER", "ADMIN"):
            failed.append({"username": username, "reason": "角色非法"})
            continue
        db.add(User(
            username=username,
            password_hash=hash_password(item.password or "Smartlearn@123456"),
            real_name=item.real_name,
            role=item.role.upper(),
        ))
        success_list.append(username)
    await db.commit()
    return success({"success": len(success_list), "failed": len(failed), "success_list": success_list, "failed_list": failed})


@router.get("/admin/audit-logs", tags=["admin"])
async def list_audit_logs(db: AsyncSession = Depends(get_db), user=Depends(require_roles("ADMIN")), limit: int = 100):
    rows = (await db.execute(select(SysAuditLog).order_by(SysAuditLog.id.desc()).limit(limit))).scalars().all()
    return success([
        {"id": a.id, "user_id": a.user_id, "action": a.action, "target_type": a.target_type,
         "target_id": a.target_id, "detail": a.detail, "created_at": a.created_at}
        for a in rows
    ])
