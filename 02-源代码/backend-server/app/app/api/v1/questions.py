from __future__ import annotations

import random

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth import require_roles
from app.core.response import success
from app.database import get_db
from app.models import ExamPaper, ExamPaperQuestion, Question
from app.schemas import PaperRandomRequest, QuestionCreate

router = APIRouter()


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
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=20, ge=1, le=100),
    q: str | None = None,
    course_id: int | None = None,      # 需求 8：组卷按课程筛选
    type: str | None = None,          # 需求 8：按题型筛选
    difficulty: int | None = None,    # 需求 8：按难度筛选
):
    """题库分页列表：默认 20 条/页（上限 100），q 支持题干模糊搜索。"""
    filters = []
    if status:
        filters.append(Question.status == status.upper())
    if q:
        filters.append(Question.text.like(f"%{q}%"))
    if course_id:
        filters.append(Question.course_id == course_id)
    if type:
        filters.append(Question.type == type.upper())
    if difficulty:
        filters.append(Question.difficulty == difficulty)
    base = select(Question).where(*filters)
    total = (await db.execute(select(func.count()).select_from(base.subquery()))).scalar() or 0
    rows = (
        await db.execute(
            base.order_by(Question.id.desc()).offset((page - 1) * page_size).limit(page_size)
        )
    ).scalars().all()
    return success({
        "items": [_question_out(item) for item in rows],
        "total": total,
        "page": page,
        "page_size": page_size,
        "pages": (total + page_size - 1) // page_size,
    })


@router.get("/questions/{question_id}", tags=["questions"])
async def get_question(question_id: int, db: AsyncSession = Depends(get_db), user=Depends(require_roles("TEACHER", "ADMIN"))):
    question = await db.get(Question, question_id)
    if not question:
        raise HTTPException(404, "题目不存在")
    return success(_question_out(question))


@router.post("/questions/drafts/approve", tags=["questions"])
async def approve_draft(payload: dict, db: AsyncSession = Depends(get_db), user=Depends(require_roles("TEACHER", "ADMIN"))):
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
