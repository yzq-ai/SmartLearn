"""DEPRECATED: Split into app.api.v1.admin, .questions, .jobs, .stats. This file is kept for backward compatibility only."""
from __future__ import annotations

import random
from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth import current_user, hash_password, require_roles
from app.core.audit import write_audit
from app.core.config import settings
from app.core.response import success
from app.database import get_db
from app.models import (
    Company, Course, CourseEnrollment, DiscussionPost, DiscussionReply, Exam, ExamPaper,
    ExamPaperQuestion, ExamRecord, JobApplication, JobPosting, JobSkillTag,
    KnowledgePoint, Question, SensitiveWord, SysAuditLog, SysConfig, User,
    WrongQuestion,
)
from app.schemas import (
    CompanyCreate, ConfigUpsert, JobCreate, PaperRandomRequest, QuestionCreate,
    ReviewDecision, SensitiveWordCreate, SkillTagCreate, UserImportRequest,
    UserPasswordReset, UserStatusUpdate,
)
from app.services.sensitive import scan_sensitive

router = APIRouter()


async def _sensitive_words(db: AsyncSession) -> list[str]:
    rows = (await db.execute(select(SensitiveWord.word))).scalars().all()
    return list(rows)


# ---------------------------------------------------------------------------
# 就业信息：先审后发
# ---------------------------------------------------------------------------
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
        review_status=0,  # 待审
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
        verify_status=0,  # 待审
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


# ---------------------------------------------------------------------------
# 管理端审核工作台
# ---------------------------------------------------------------------------
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
            post.status = 0  # 下架
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


# ---------------------------------------------------------------------------
# 题库 CRUD（教师）
# ---------------------------------------------------------------------------
def _question_out(q: Question) -> dict:
    return {
        "id": q.id,
        "type": q.type,
        "content": q.text,
        "options": q.options or [],
        "answer": q.answer,
        "analysis": q.analysis or "",
        "difficulty": q.difficulty,
        "score": q.score,
        "kp_ids": q.kp_ids or [],
        "course_id": q.course_id,
        "source": q.source,
        "status": q.status,
    }


@router.get("/questions", tags=["questions"])
async def list_questions(
    db: AsyncSession = Depends(get_db),
    user=Depends(require_roles("TEACHER", "ADMIN")),
    status: str | None = None,
):
    statement = select(Question).order_by(Question.id.desc())
    if status:
        statement = statement.where(Question.status == status.upper())
    rows = (await db.execute(statement)).scalars().all()
    return success([_question_out(q) for q in rows])


@router.get("/questions/{question_id}", tags=["questions"])
async def get_question(question_id: int, db: AsyncSession = Depends(get_db), user=Depends(require_roles("TEACHER", "ADMIN"))):
    question = await db.get(Question, question_id)
    if not question:
        raise HTTPException(404, "题目不存在")
    return success(_question_out(question))


@router.post("/questions/drafts/approve", tags=["questions"])
async def approve_draft(payload: dict, db: AsyncSession = Depends(get_db), user=Depends(require_roles("TEACHER", "ADMIN"))):
    """教师采纳 AI 草稿题：DRAFT → PUBLISHED。"""
    question_id = payload.get("question_id")
    question = await db.get(Question, question_id)
    if not question:
        raise HTTPException(404, "题目不存在")
    if question.status == "PUBLISHED":
        raise HTTPException(409, "题目已发布")
    question.status = "PUBLISHED"
    await db.commit()
    await db.refresh(question)
    return success(_question_out(question))


@router.delete("/questions/drafts/{question_id}", tags=["questions"])
async def discard_draft(question_id: int, db: AsyncSession = Depends(get_db), user=Depends(require_roles("TEACHER", "ADMIN"))):
    """丢弃 AI 草稿题（DRAFT 隔离，30 天未处理由 Celery 清理）。"""
    question = await db.get(Question, question_id)
    if not question:
        raise HTTPException(404, "题目不存在")
    if question.status != "DRAFT":
        raise HTTPException(409, "只能丢弃草稿题")
    await db.delete(question)
    await db.commit()
    return success({"id": question_id, "deleted": True})


@router.post("/papers/random", tags=["questions"])
async def random_paper(payload: PaperRandomRequest, db: AsyncSession = Depends(get_db), user=Depends(require_roles("TEACHER", "ADMIN"))):
    """规则抽题组卷：按题型×难度×知识点筛选 PUBLISHED 题，随机抽 count 题。"""
    statement = select(Question).where(Question.status == "PUBLISHED", Question.course_id == payload.course_id)
    if payload.type:
        statement = statement.where(Question.type == payload.type.upper())
    if payload.difficulty:
        statement = statement.where(Question.difficulty == payload.difficulty)
    pool = (await db.execute(statement)).scalars().all()

    if payload.kp_ids:
        kp_set = set(payload.kp_ids)
        pool = [q for q in pool if (q.kp_ids and set(q.kp_ids) & kp_set)]

    selected = random.sample(pool, min(len(pool), payload.count))
    if not selected:
        raise HTTPException(404, "题库中没有符合条件的题目")

    paper = ExamPaper(title=payload.title, course_id=payload.course_id, total_score=0, created_by=user.id)
    db.add(paper)
    await db.flush()
    total = 0
    for idx, question in enumerate(selected):
        db.add(ExamPaperQuestion(paper_id=paper.id, question_id=question.id, score=question.score, sort_order=idx))
        total += int(question.score or 0)
    paper.total_score = total
    await db.commit()
    await db.refresh(paper)
    return success({
        "id": paper.id, "title": paper.title, "total_score": paper.total_score,
        "questions": [{"id": q.id, "type": q.type, "text": q.text, "score": q.score} for q in selected],
    })


@router.post("/questions", tags=["questions"])
async def create_question(payload: QuestionCreate, db: AsyncSession = Depends(get_db), user=Depends(require_roles("TEACHER", "ADMIN"))):
    question = Question(
        type=payload.type.upper(),
        text=payload.content,
        answer=payload.answer,
        options=payload.options,
        analysis=payload.analysis,
        difficulty=payload.difficulty,
        score=payload.score,
        kp_ids=payload.kp_ids,
        course_id=payload.course_id,
        source="MANUAL",
        status="PUBLISHED",
        created_by=user.id,
    )
    db.add(question)
    await db.commit()
    await db.refresh(question)
    return success(_question_out(question))


@router.put("/questions/{question_id}", tags=["questions"])
async def update_question(
    question_id: int,
    payload: QuestionCreate,
    db: AsyncSession = Depends(get_db),
    user=Depends(require_roles("TEACHER", "ADMIN")),
):
    question = await db.get(Question, question_id)
    if not question:
        raise HTTPException(404, "题目不存在")
    question.type = payload.type.upper()
    question.text = payload.content
    question.answer = payload.answer
    question.options = payload.options
    question.analysis = payload.analysis
    question.difficulty = payload.difficulty
    question.score = payload.score
    question.kp_ids = payload.kp_ids
    question.course_id = payload.course_id
    await db.commit()
    await db.refresh(question)
    return success(_question_out(question))


# ---------------------------------------------------------------------------
# 教师学情看板
# ---------------------------------------------------------------------------
@router.get("/stats/learning", tags=["stats"])
async def learning_stats(db: AsyncSession = Depends(get_db), user=Depends(require_roles("TEACHER", "ADMIN"))):
    # 课程与选课/进度概览
    courses = (await db.execute(select(Course))).scalars().all()
    # 真实选课人数（按 course_enrollment 聚合，而非 course 冗余字段）
    enrollment_counts: dict[int, int] = dict(
        (await db.execute(
            select(CourseEnrollment.course_id, func.count(CourseEnrollment.id))
            .group_by(CourseEnrollment.course_id)
        )).all()
    )
    course_rows = []
    for course in courses:
        exam_count = len((await db.execute(select(Exam.id).where(Exam.course_id == course.id))).scalars().all())
        course_rows.append({
            "id": course.id,
            "title": course.title,
            "teacher": course.teacher,
            "student_count": enrollment_counts.get(course.id, 0) or course.student_count,
            "exam_count": exam_count,
        })

    # 高频错题 TOP（按归集次数）
    wrong_rows = (
        await db.execute(
            select(Question.id, Question.text, func.count(WrongQuestion.id).label("cnt"))
            .join(WrongQuestion, WrongQuestion.question_id == Question.id)
            .group_by(Question.id, Question.text)
            .order_by(func.count(WrongQuestion.id).desc())
            .limit(10)
        )
    ).all()

    # 考试提交概览
    exam_rows = (
        await db.execute(
            select(Exam.id, Exam.title, func.count(ExamRecord.id).label("records"))
            .outerjoin(ExamRecord, ExamRecord.exam_id == Exam.id)
            .group_by(Exam.id, Exam.title)
        )
    ).all()

    return success({
        "courses": course_rows,
        "top_wrong": [{"question_id": r[0], "text": r[1], "count": r[2]} for r in wrong_rows],
        "exams": [{"id": r[0], "title": r[1], "records": r[2]} for r in exam_rows],
    })


# ---------------------------------------------------------------------------
# 管理端数据大屏
# ---------------------------------------------------------------------------
@router.get("/admin/stats/dashboard", tags=["admin"])
async def admin_dashboard(db: AsyncSession = Depends(get_db), user=Depends(require_roles("ADMIN"))):
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


@router.get("/admin/integrations", tags=["admin"])
async def integrations_status(user=Depends(require_roles("ADMIN"))):
    """外部服务集成状态：OBS / Push / RAG 的配置与连通性探测。"""
    from app.services.obs import check_obs
    from app.services.push_service import check_push
    from app.services.vector_store import check_vector

    return success({
        "obs": check_obs(),
        "push": check_push(),
        "vector": check_vector(),
    })


# ---------------------------------------------------------------------------
# 异步任务触发（管理端手动触发，生产由 Celery Beat 定时执行）
# ---------------------------------------------------------------------------
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


# ---------------------------------------------------------------------------
# 敏感词库 CRUD（管理员）
# ---------------------------------------------------------------------------
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


# ---------------------------------------------------------------------------
# 系统配置 CRUD（管理员）
# ---------------------------------------------------------------------------
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


# ---------------------------------------------------------------------------
# 技能标签字典 CRUD（管理员）
# ---------------------------------------------------------------------------
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


# ---------------------------------------------------------------------------
# 用户管理（管理员）
# ---------------------------------------------------------------------------
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


# ---------------------------------------------------------------------------
# 审计日志查询（只增不删）
# ---------------------------------------------------------------------------
@router.get("/admin/audit-logs", tags=["admin"])
async def list_audit_logs(db: AsyncSession = Depends(get_db), user=Depends(require_roles("ADMIN")), limit: int = 100):
    rows = (await db.execute(select(SysAuditLog).order_by(SysAuditLog.id.desc()).limit(limit))).scalars().all()
    return success([
        {"id": a.id, "user_id": a.user_id, "action": a.action, "target_type": a.target_type,
         "target_id": a.target_id, "detail": a.detail, "created_at": a.created_at}
        for a in rows
    ])
