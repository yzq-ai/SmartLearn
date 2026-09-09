from __future__ import annotations

import json
import logging

from fastapi import APIRouter, Depends, HTTPException
from fastapi.responses import StreamingResponse
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth import current_user
from app.core.config import settings
from app.core.response import success
from app.database import get_db
from app.db.redis import get_rate_limiter
from app.models import AiChatLog, KnowledgePoint, Question, Section, Chapter, StudyPlan
from app.schemas import AiFeedbackRequest
from app.schemas.ai import (
    CourseQaRequest,
    CourseQaResponse,
    InterviewStartRequest,
    InterviewStartResponse,
    InterviewTurnRequest,
    InterviewTurnResponse,
    JobExplainRequest,
    JobExplainResponse,
    PlanRequest,
    PlanResponse,
    QuestionGenRequest,
    QuestionGenResponse,
    ResumeOptimizeRequest,
    ResumeOptimizeResponse,
    SummaryRequest,
    SummaryResponse,
    WrongAnswerAnalysis,
    WrongAnswerInput,
)
from app.services.ai_security import InMemoryRateLimiter, audit
from app.services.ai_service import (
    analyze_wrong_answer,
    course_qa,
    generate_plan,
    generate_questions,
    interview_start_rules,
    interview_turn_rules,
    job_explain,
    optimize_resume,
    summarize,
)
from app.services.vector_store import get_vector_store

router = APIRouter(prefix="/ai", tags=["ai"])
logger = logging.getLogger("smartlearn.ai.routes")

_in_memory_limiter = InMemoryRateLimiter(limit=max(1, int(settings.ai_requests_per_minute)))
_redis_limiter = get_rate_limiter()


async def _check_limit(scene: str, user: object) -> None:
    user_id = getattr(user, "id", 0)
    if _redis_limiter is not None:
        allowed = await _redis_limiter.allow(int(user_id), max(1, int(settings.ai_requests_per_minute)))
    else:
        allowed = _in_memory_limiter.allow(int(user_id))
    if not allowed:
        audit(scene, user_id, True)
        raise HTTPException(status_code=429, detail="AI_RATE_LIMITED")
    audit(scene, user_id, False)


def _service_error() -> HTTPException:
    return HTTPException(status_code=503, detail="AI_UNAVAILABLE")


async def _log_ai(db: AsyncSession, user, scene: str, ref_type: str, ref_id, input_text: str, output_obj: dict) -> int:
    """写入 AI 审计日志并返回 log_id（用于端侧 👍👎 反馈）。失败不阻断响应。"""
    try:
        log = AiChatLog(
            user_id=user.id,
            scene=scene,
            ref_type=ref_type,
            ref_id=ref_id,
            input_text=input_text[:500],
            output_text=json.dumps(output_obj, ensure_ascii=False, default=str)[:2000],
        )
        db.add(log)
        await db.commit()
        await db.refresh(log)
        return log.id
    except Exception:  # noqa: BLE001
        return 0


@router.post("/wrong-answer/analyze")
async def wrong_answer(payload: WrongAnswerInput, db: AsyncSession = Depends(get_db), user=Depends(current_user)):
    await _check_limit("wrong_answer", user)
    try:
        result = analyze_wrong_answer(payload)
        log_id = await _log_ai(db, user, "WRONG_ANALYSIS", "QUESTION", 0, payload.question, result)
        return success({**result, "log_id": log_id})
    except Exception as exc:
        logger.error("ai_service_failed", extra={"scene": "wrong_answer", "user": str(user.id), "error_type": type(exc).__name__})
        raise _service_error() from None


@router.post("/resume/optimize")
async def resume_optimize(payload: ResumeOptimizeRequest, db: AsyncSession = Depends(get_db), user=Depends(current_user)):
    await _check_limit("resume_optimize", user)
    try:
        result = optimize_resume(payload)
        log_id = await _log_ai(db, user, "RESUME", "RESUME", 0, payload.resume, result)
        return success({**result, "log_id": log_id})
    except Exception as exc:
        logger.error("ai_service_failed", extra={"scene": "resume_optimize", "user": str(user.id), "error_type": type(exc).__name__})
        raise _service_error() from None


@router.post("/job-explain")
async def job_explain_route(payload: JobExplainRequest, db: AsyncSession = Depends(get_db), user=Depends(current_user)):
    await _check_limit("job_explain", user)
    try:
        # 传 job_id 时从库里取真实岗位 JD/技能权重与学生画像，喂给真实 AI
        context = ""
        job_title = payload.job_title
        match_score = payload.match_score
        matched_tags = payload.matched_tags
        gap_tags = payload.gap_tags
        required_skills = payload.required_skills
        if payload.job_id:
            from sqlalchemy import select as _select

            from app.models import JobPosting, StudentProfile

            job = await db.get(JobPosting, payload.job_id)
            if job:
                job_title = job.title
                weights = job.skill_weights or {}
                weight_desc = "、".join(f"{k}（权重{v}）" for k, v in weights.items()) or "未配置"
                required_skills = list(weights.keys()) or (job.required_skills or "").split(",")
                required_skills = [s.strip() for s in required_skills if s.strip()]
                profile = (
                    await db.execute(_select(StudentProfile).where(StudentProfile.user_id == user.id))
                ).scalar_one_or_none()
                profile_desc = "暂无画像"
                scores = profile.skill_scores if profile else None
                if scores:
                    top = sorted(scores.items(), key=lambda kv: -kv[1])[:8]
                    profile_desc = "、".join(f"{k}{v}分" for k, v in top)
                    # 前端没传匹配数据时，用真实画像对岗位技能重算 matched/gap
                    if not payload.matched_tags and not payload.gap_tags and required_skills:
                        matched_tags = [s for s in required_skills if scores.get(s, 0) >= 60]
                        gap_tags = [s for s in required_skills if scores.get(s, 0) < 60]
                        weight_sum = sum(float(w) for w in weights.values()) if weights else len(required_skills)
                        if weight_sum > 0 and weights:
                            match_score = round(
                                sum(scores.get(k, 0) * float(v) for k, v in weights.items()) / (100 * weight_sum) * 100, 1
                            )
                        elif required_skills:
                            match_score = round(
                                sum(scores.get(s, 0) for s in required_skills) / (100 * len(required_skills)) * 100, 1
                            )
                salary_desc = f"{job.salary_min}-{job.salary_max} 元" if job.salary_min else "面议"
                context = (
                    f"\n【岗位真实 JD】{job.description}\n"
                    f"【技能权重】{weight_desc}\n"
                    f"【薪资/城市/学历】{salary_desc} · {job.city or '不限'} · {job.education_req or '不限'}\n"
                    f"【学生真实画像（平台技能分，满分100）】{profile_desc}\n"
                )
        # 用库里重算的真值回填 payload，交给判分器与 LLM
        payload.job_title = job_title
        payload.match_score = match_score
        payload.matched_tags = matched_tags
        payload.gap_tags = gap_tags
        payload.required_skills = required_skills
        result = job_explain(payload, extra_context=context)
        log_id = await _log_ai(db, user, "JOB_EXPLAIN", "JOB", payload.job_id or 0, job_title, result)
        return success({**result, "log_id": log_id})
    except Exception as exc:
        logger.error("ai_service_failed", extra={"scene": "job_explain", "user": str(user.id), "error_type": type(exc).__name__})
        raise _service_error() from None


@router.post("/summary")
async def summary_route(payload: SummaryRequest, db: AsyncSession = Depends(get_db), user=Depends(current_user)):
    await _check_limit("summary", user)
    try:
        result = summarize(payload)
        log_id = await _log_ai(db, user, "SUMMARY", "COURSE", getattr(payload, "course_id", 0), payload.text, result)
        return success({**result, "log_id": log_id})
    except Exception as exc:
        logger.error("ai_service_failed", extra={"scene": "summary", "user": str(user.id), "error_type": type(exc).__name__})
        raise _service_error() from None


@router.post("/plan")
async def plan_route(payload: PlanRequest, db: AsyncSession = Depends(get_db), user=Depends(current_user)):
    await _check_limit("plan", user)
    try:
        result = generate_plan(payload)
        db.add(StudyPlan(
            user_id=user.id,
            goal=payload.goal,
            plan_json={"goal": payload.goal, "daily_minutes": payload.daily_minutes, "plan": result["plan"]},
            ai_generated=1,
            status="ACTIVE",
        ))
        await db.commit()
        return success(result)
    except Exception as exc:
        logger.error("ai_service_failed", extra={"scene": "plan", "user": str(user.id), "error_type": type(exc).__name__})
        raise _service_error() from None


@router.post("/interview/start")
async def interview_start(payload: InterviewStartRequest, user=Depends(current_user)):
    await _check_limit("interview", user)
    try:
        return success(interview_start_rules(payload.job_title, payload.required_skills))
    except Exception as exc:
        logger.error("ai_service_failed", extra={"scene": "interview", "user": str(user.id), "error_type": type(exc).__name__})
        raise _service_error() from None


@router.post("/interview/turn")
async def interview_turn(payload: InterviewTurnRequest, user=Depends(current_user)):
    await _check_limit("interview", user)
    try:
        return success(interview_turn_rules(payload.job_title, payload.question, payload.answer, payload.turn))
    except Exception as exc:
        logger.error("ai_service_failed", extra={"scene": "interview", "user": str(user.id), "error_type": type(exc).__name__})
        raise _service_error() from None


@router.post("/questions/draft")
async def questions_draft(payload: QuestionGenRequest, db: AsyncSession = Depends(get_db), user=Depends(current_user)):
    await _check_limit("question_gen", user)
    try:
        result = generate_questions(payload)
        kp_ids: list[int] = []
        if payload.kp_names:
            rows = (await db.execute(select(KnowledgePoint).where(KnowledgePoint.name.in_(payload.kp_names)))).scalars().all()
            kp_ids = [k.id for k in rows]
        drafts = []
        for q in result["questions"]:
            question = Question(
                type=q["type"].upper(),
                text=q["content"],
                options=q.get("options"),
                answer=q.get("answer", ""),
                analysis=q.get("analysis"),
                difficulty=q.get("difficulty", payload.difficulty),
                score=5,
                kp_ids=kp_ids,
                course_id=payload.course_id,
                source="AI",
                status="DRAFT",
                created_by=user.id,
            )
            db.add(question)
            drafts.append(question)
        await db.commit()
        return success({
            "questions": [
                {"id": q.id, "type": q.type, "content": q.text, "answer": q.answer,
                 "difficulty": q.difficulty, "status": q.status, "kp_ids": q.kp_ids}
                for q in drafts
            ],
            "source": result["source"],
        })
    except Exception as exc:
        logger.error("ai_service_failed", extra={"scene": "question_gen", "user": str(user.id), "error_type": type(exc).__name__})
        raise _service_error() from None


@router.post("/course-qa")
async def course_qa_route(payload: CourseQaRequest, db: AsyncSession = Depends(get_db), user=Depends(current_user)):
    await _check_limit("course_qa", user)
    try:
        rows = (
            await db.execute(
                select(Section.content, Chapter.title, Section.title)
                .join(Chapter, Chapter.id == Section.chapter_id)
                .where(Chapter.course_id == payload.course_id)
            )
        ).all()
        passages = [
            {"content": f"{chapter_title} / {section_title}：{content or ''}", "source": f"{chapter_title} · {section_title}"}
            for content, chapter_title, section_title in rows
        ]
        refs = get_vector_store().search(passages, payload.query)
        result = course_qa(payload.query, refs)

        log = AiChatLog(
            user_id=user.id,
            scene="COURSE_QA",
            ref_type="COURSE",
            ref_id=payload.course_id,
            input_text=payload.query,
            output_text=result["answer"],
            refs=result["refs"],
        )
        db.add(log)
        await db.commit()
        await db.refresh(log)
        return success({**result, "log_id": log.id})
    except Exception as exc:
        logger.error("ai_service_failed", extra={"scene": "course_qa", "user": str(user.id), "error_type": type(exc).__name__})
        raise _service_error() from None


@router.post("/feedback")
async def ai_feedback(payload: AiFeedbackRequest, db: AsyncSession = Depends(get_db), user=Depends(current_user)):
    log = await db.get(AiChatLog, payload.log_id)
    if not log or log.user_id != user.id:
        raise HTTPException(404, "记录不存在")
    log.feedback = payload.feedback
    await db.commit()
    return success({"log_id": log.id, "feedback": log.feedback})


@router.post("/chat/stream")
async def ai_chat_stream(payload: CourseQaRequest, db: AsyncSession = Depends(get_db), user=Depends(current_user)):
    await _check_limit("course_qa", user)

    async def retrieve():
        rows = (
            await db.execute(
                select(Section.content, Chapter.title, Section.title)
                .join(Chapter, Chapter.id == Section.chapter_id)
                .where(Chapter.course_id == payload.course_id)
            )
        ).all()
        passages = [
            {"content": f"{chapter_title} / {section_title}：{content or ''}", "source": f"{chapter_title} · {section_title}"}
            for content, chapter_title, section_title in rows
        ]
        return get_vector_store().search(passages, payload.query)

    try:
        refs = await retrieve()
        result = course_qa(payload.query, refs)
        answer = result["answer"]

        async def event_stream():
            for chunk in [answer[i:i + 8] for i in range(0, len(answer), 8)] or [""]:
                yield f"data: {json.dumps({'delta': chunk}, ensure_ascii=False)}\n\n"
            yield f"data: {json.dumps({'done': True, 'refs': refs}, ensure_ascii=False)}\n\n"

        log = AiChatLog(
            user_id=user.id, scene="COURSE_QA", ref_type="COURSE", ref_id=payload.course_id,
            input_text=payload.query, output_text=answer, refs=refs,
        )
        db.add(log)
        await db.commit()
        return StreamingResponse(event_stream(), media_type="text/event-stream")
    except Exception as exc:
        logger.error("ai_service_failed", extra={"scene": "course_qa", "user": str(user.id), "error_type": type(exc).__name__})
        raise _service_error() from None
