"""交卷异步判分/错题/掌握度链。"""
from __future__ import annotations

import json
import logging

from sqlalchemy import select

from app.models import (
    ExamAnswer,
    ExamRecord,
    Question,
    WrongQuestion,
    StudentKpMastery,
    KnowledgePoint,
)
from app.services.grading import grade_answer
from app.tasks.celery_app import celery_app
from app.tasks.sync_db import SyncSessionLocal

logger = logging.getLogger(__name__)


@celery_app.task(name="app.tasks.grading_tasks.grade_exam_record")
def grade_exam_record(record_id: int) -> dict:
    """异步判分：客观题即时判，主观题标记等待教师批改。"""
    db = SyncSessionLocal()
    try:
        record = db.execute(select(ExamRecord).where(ExamRecord.id == record_id)).scalar_one_or_none()
        if not record or record.status not in ("IN_PROGRESS", "EXPIRED"):
            return {"error": "invalid record"}
        answers = db.execute(select(ExamAnswer).where(ExamAnswer.record_id == record_id)).scalars().all()
        objective_score = 0.0
        has_subjective = False
        for ans in answers:
            question = db.execute(select(Question).where(Question.id == ans.question_id)).scalar_one_or_none()
            if not question:
                continue
            if question.type == "SHORT":
                has_subjective = True
                continue
            result = grade_answer(question.type, _parse_answer(question.answer), _parse_answer(ans.answer), question.score)
            ans.is_correct = 1 if result["correct"] else 0
            ans.score = result["score"]
            objective_score += result["score"]
        record.objective_score = objective_score
        if has_subjective:
            record.status = "GRADING"
        else:
            record.status = "GRADED"
            record.score = objective_score
            record.total = objective_score
        db.commit()
        if not has_subjective:
            collect_wrong_questions.delay(record_id)
            refresh_mastery.delay(record.user_id)
        return {"record_id": record_id, "status": record.status, "objective_score": objective_score}
    except Exception as e:
        logger.error("grade_exam_record failed: %s", e)
        return {"error": str(e)}
    finally:
        db.close()


@celery_app.task(name="app.tasks.grading_tasks.collect_wrong_questions")
def collect_wrong_questions(record_id: int) -> dict:
    db = SyncSessionLocal()
    try:
        answers = db.execute(
            select(ExamAnswer).where(ExamAnswer.record_id == record_id, ExamAnswer.is_correct == 0)
        ).scalars().all()
        record = db.execute(select(ExamRecord).where(ExamRecord.id == record_id)).scalar_one_or_none()
        if not record:
            return {"error": "record not found"}
        count = 0
        for ans in answers:
            existing = db.execute(
                select(WrongQuestion).where(WrongQuestion.user_id == record.user_id, WrongQuestion.question_id == ans.question_id)
            ).scalar_one_or_none()
            if existing:
                existing.wrong_count += 1
                existing.is_mastered = 0
            else:
                db.add(WrongQuestion(user_id=record.user_id, question_id=ans.question_id, my_answer=ans.answer, source_type="EXAM", source_id=record.exam_id))
            count += 1
        db.commit()
        return {"collected": count}
    except Exception as e:
        logger.error("collect_wrong_questions failed: %s", e)
        return {"error": str(e)}
    finally:
        db.close()


@celery_app.task(name="app.tasks.grading_tasks.refresh_mastery")
def refresh_mastery(user_id: int) -> dict:
    db = SyncSessionLocal()
    try:
        from app.tasks.jobs import refresh_profile
        refresh_profile.delay(user_id)
        return {"user_id": user_id, "triggered": True}
    finally:
        db.close()


def _parse_answer(raw: str) -> str | list[str]:
    try:
        parsed = json.loads(raw)
        if isinstance(parsed, list):
            return parsed
        return raw
    except (json.JSONDecodeError, TypeError):
        return raw
