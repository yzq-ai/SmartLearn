"""DEPRECATED: Moved to app.api.v1.ai. This file is kept for backward compatibility only."""
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
    # Do not expose provider errors, request text, or stack details to clients.
    return HTTPException(status_code=503, detail="AI_UNAVAILABLE")


@router.post("/wrong-answer/analyze")
async def wrong_answer(payload: WrongAnswerInput, user=Depends(current_user)):
    await _check_limit("wrong_answer", user)
    try:
        return success(analyze_wrong_answer(payload))
    except Exception as exc:
        logger.error("ai_service_failed", extra={"scene": "wrong_answer", "user": str(user.id), "error_type": type(exc).__name__})
        raise _service_error() from None


@router.post("/resume/optimize")
async def resume_optimize(payload: ResumeOptimizeRequest, user=Depends(current_user)):
    await _check_limit("resume_optimize", user)
    try:
        return success(optimize_resume(payload))
    except Exception as exc:
        logger.error("ai_service_failed", extra={"scene": "resume_optimize", "user": str(user.id), "error_type": type(exc).__name__})
        raise _service_error() from None


@router.post("/job-explain")
async def job_explain_route(payload: JobExplainRequest, user=Depends(current_user)):
    await _check_limit("job_explain", user)
    try:
        return success(job_explain(payload))
    except Exception as exc:
        logger.error("ai_service_failed", extra={"scene": "job_explain", "user": str(user.id), "error_type": type(exc).__name__})
        raise _service_error() from None


@router.post("/summary")
async def summary_route(payload: SummaryRequest, user=Depends(current_user)):
    await _check_limit("summary", user)
    try:
        return success(summarize(payload))
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
    """生成题目并落库为 DRAFT（source=AI），教师采纳后才 PUBLISHED。"""
    await _check_limit("question_gen", user)
    try:
        result = generate_questions(payload)
        # 解析知识点 id
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
    """课程问答（RAG）：检索本课程小节内容，基于资料作答，无命中标注通用知识。"""
    await _check_limit("course_qa", user)
    try:
        # 检索该课程所有小节内容
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

        # 审计入库
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
    """AI 结果赞踩（1 赞 / -1 踩），落 ai_chat_log.feedback。"""
    log = await db.get(AiChatLog, payload.log_id)
    if not log or log.user_id != user.id:
        raise HTTPException(404, "记录不存在")
    log.feedback = payload.feedback
    await db.commit()
    return success({"log_id": log.id, "feedback": log.feedback})


@router.post("/chat/stream")
async def ai_chat_stream(payload: CourseQaRequest, db: AsyncSession = Depends(get_db), user=Depends(current_user)):
    """课程问答 SSE 流式：逐字透传答案 + 结尾返回引用。"""
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
