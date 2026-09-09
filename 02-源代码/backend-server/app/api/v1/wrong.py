from __future__ import annotations

import json
from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.auth import current_user
from app.core.response import success
from app.database import get_db
from app.models import WrongQuestion

router = APIRouter()


def _answer_from_storage(answer: str):
    try:
        return json.loads(answer)
    except (TypeError, json.JSONDecodeError):
        return answer


def _wrong_out(row: WrongQuestion) -> dict:
    return {
        "id": row.id,
        "question_id": row.question_id,
        "question_type": row.question.type if row.question else None,
        "question_text": row.question.text if row.question else "",
        "correct_answer": row.question.answer if row.question else "",
        "analysis": (row.question.analysis or "") if row.question else "",
        "my_answer": _answer_from_storage(row.my_answer) if row.my_answer else None,
        "source_type": row.source_type,
        "wrong_count": row.wrong_count,
        "is_mastered": row.is_mastered,
    }


@router.get("/wrong-questions", tags=["wrong"])
async def list_wrong_questions(db: AsyncSession = Depends(get_db), user=Depends(current_user)):
    rows = (
        await db.execute(
            select(WrongQuestion)
            .options(selectinload(WrongQuestion.question))
            .where(WrongQuestion.user_id == user.id)
            .order_by(WrongQuestion.updated_at.desc())
        )
    ).scalars().all()
    return success([_wrong_out(row) for row in rows])


@router.put("/wrong-questions/{wrong_id}/mastered", tags=["wrong"])
async def mark_wrong_mastered(wrong_id: int, db: AsyncSession = Depends(get_db), user=Depends(current_user)):
    row = await db.get(WrongQuestion, wrong_id)
    if not row or row.user_id != user.id:
        raise HTTPException(404, "错题不存在")
    row.is_mastered = 1
    row.mastered_at = datetime.utcnow()
    await db.commit()
    return success({"id": row.id, "is_mastered": row.is_mastered})
