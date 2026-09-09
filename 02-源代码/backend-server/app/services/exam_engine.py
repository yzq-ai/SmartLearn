"""Exam state machine and snapshot logic.

State transitions: IN_PROGRESS → GRADING (has subjective) / SUBMITTED (all objective)
                    IN_PROGRESS → EXPIRED (deadline exceeded)
                    GRADING → GRADED (after teacher manual grading)

All DB-mutating functions accept an AsyncSession for dependency injection;
pure helpers have no DB dependency and are directly unit-testable.
"""
from __future__ import annotations

import json
from datetime import datetime, timedelta

from fastapi import HTTPException
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models import Exam, ExamAnswer, ExamRecord, Question
from app.services import grade_exam
from app.services.assessment_service import apply_exam_results


def answer_to_storage(answer: str | list[str]) -> str:
    return json.dumps(answer, ensure_ascii=False, separators=(",", ":"))


def answer_from_storage(answer: str) -> str | list[str]:
    try:
        return json.loads(answer)
    except (TypeError, json.JSONDecodeError):
        return answer


def record_out(record: ExamRecord) -> dict:
    return {
        "record_id": record.id,
        "exam_id": record.exam_id,
        "status": record.status,
        "started_at": record.started_at,
        "deadline_at": record.deadline_at,
        "submitted_at": record.submitted_at,
        "score": record.score,
        "total": record.total,
        "passed": record.passed,
        "answers": [
            {"question_id": answer.question_id, "answer": answer_from_storage(answer.answer)}
            for answer in sorted(record.answers, key=lambda item: item.question_id)
        ],
    }


async def get_exam(db: AsyncSession, exam_id: int) -> Exam:
    exam = (
        await db.execute(
            select(Exam).options(selectinload(Exam.questions)).where(Exam.id == exam_id)
        )
    ).scalar_one_or_none()
    if not exam:
        raise HTTPException(404, "考试不存在")
    return exam


async def get_record(db: AsyncSession, exam_id: int, user_id: int, *, lock: bool = False) -> ExamRecord | None:
    statement = (
        select(ExamRecord)
        .options(selectinload(ExamRecord.answers))
        .where(ExamRecord.exam_id == exam_id, ExamRecord.user_id == user_id)
    )
    if lock:
        statement = statement.with_for_update()
    return (await db.execute(statement)).scalar_one_or_none()


def ensure_open(record: ExamRecord, now: datetime) -> None:
    if record.status == "SUBMITTED":
        raise HTTPException(409, "考试已提交，请勿重复提交")
    if record.status == "EXPIRED" or now >= record.deadline_at:
        record.status = "EXPIRED"
        raise HTTPException(409, "考试已截止")


def validate_answers(exam: Exam, answers) -> None:
    valid_ids = {question.id for question in exam.questions}
    submitted_ids = [answer.question_id for answer in answers]
    if len(submitted_ids) != len(set(submitted_ids)):
        raise HTTPException(422, "答案中包含重复题目")
    invalid_ids = sorted(set(submitted_ids) - valid_ids)
    if invalid_ids:
        raise HTTPException(422, f"答案包含不属于本考试的题目: {invalid_ids}")


async def save_answers(db: AsyncSession, record: ExamRecord, answers) -> None:
    existing = {answer.question_id: answer for answer in record.answers}
    for incoming in answers:
        stored = answer_to_storage(incoming.answer)
        if incoming.question_id in existing:
            existing[incoming.question_id].answer = stored
            existing[incoming.question_id].updated_at = datetime.utcnow()
        else:
            answer = ExamAnswer(record_id=record.id, question_id=incoming.question_id, answer=stored)
            db.add(answer)
            record.answers.append(answer)


async def prepare_open_record(db: AsyncSession, exam_id: int, user_id: int) -> ExamRecord:
    record = await get_record(db, exam_id, user_id, lock=True)
    if not record:
        raise HTTPException(409, "请先开始考试")
    try:
        ensure_open(record, datetime.utcnow())
    except HTTPException:
        await db.commit()
        raise
    return record


async def do_submit(db: AsyncSession, exam: Exam, record: ExamRecord, payload, exam_id: int) -> dict:
    validate_answers(exam, payload.answers)
    await save_answers(db, record, payload.answers)

    answer_map = {answer.question_id: answer_from_storage(answer.answer) for answer in record.answers}
    questions = list(exam.questions)
    result = grade_exam(
        [{"id": q.id, "type": q.type, "answer": q.answer, "score": q.score} for q in questions],
        answer_map,
    )
    record.status = "GRADING" if result["has_subjective"] else "SUBMITTED"
    record.submitted_at = datetime.utcnow()
    record.score = result["score"]
    record.objective_score = result["objective_score"]
    record.total = result["total"]
    record.passed = result["score"] >= result["total"] * 0.6
    await apply_exam_results(db, record, questions, answer_map, result)
    await db.commit()
    return {"exam_id": exam_id, **result, "passed": record.passed}


async def grade_saved_answers(db: AsyncSession, exam: Exam, record: ExamRecord, submit_type: str) -> dict:
    answer_map = {answer.question_id: answer_from_storage(answer.answer) for answer in record.answers}
    questions = list(exam.questions)
    result = grade_exam(
        [{"id": q.id, "type": q.type, "answer": q.answer, "score": q.score} for q in questions],
        answer_map,
    )
    record.status = "GRADING" if result["has_subjective"] else "SUBMITTED"
    record.submit_type = submit_type
    record.submitted_at = datetime.utcnow()
    record.score = result["score"]
    record.objective_score = result["objective_score"]
    record.total = result["total"]
    record.passed = result["score"] >= result["total"] * 0.6
    await apply_exam_results(db, record, questions, answer_map, result)
    await db.commit()
    return {"record_id": record.id, **result, "passed": record.passed}


async def start_exam_record(
    db: AsyncSession, exam_id: int, user_id: int, duration_minutes: int,
) -> ExamRecord:
    await get_exam(db, exam_id)
    record = await get_record(db, exam_id, user_id)
    if record:
        if record.status == "SUBMITTED":
            raise HTTPException(409, "考试已提交，不能重复开始")
        if datetime.utcnow() >= record.deadline_at:
            record.status = "EXPIRED"
            await db.commit()
            raise HTTPException(409, "考试已截止")
        return record

    now = datetime.utcnow()
    record = ExamRecord(
        user_id=user_id,
        exam_id=exam_id,
        status="IN_PROGRESS",
        started_at=now,
        deadline_at=now + timedelta(minutes=duration_minutes),
    )
    db.add(record)
    try:
        await db.commit()
    except IntegrityError:
        await db.rollback()
        record = await get_record(db, exam_id, user_id)
        if not record:
            raise
    await db.refresh(record, attribute_names=["answers"])
    return record


async def get_exam_state(db: AsyncSession, exam_id: int, user_id: int) -> ExamRecord:
    await get_exam(db, exam_id)
    record = await get_record(db, exam_id, user_id)
    if not record:
        raise HTTPException(404, "尚未开始考试")
    if record.status == "IN_PROGRESS" and datetime.utcnow() >= record.deadline_at:
        record.status = "EXPIRED"
        await db.commit()
    return record


async def save_exam_answers_flow(
    db: AsyncSession, exam_id: int, user_id: int, payload,
) -> ExamRecord:
    exam = await get_exam(db, exam_id)
    record = await get_record(db, exam_id, user_id, lock=True)
    if not record:
        raise HTTPException(409, "请先开始考试")
    try:
        ensure_open(record, datetime.utcnow())
    except HTTPException:
        await db.commit()
        raise
    validate_answers(exam, payload.answers)
    await save_answers(db, record, payload.answers)
    await db.commit()
    return await get_record(db, exam_id, user_id)


async def create_exam_flow(db: AsyncSession, payload, user_id: int) -> Exam:
    exam = Exam(
        title=payload.title,
        course_id=payload.course_id,
        duration_min=payload.duration_min,
        pass_score=payload.pass_score,
        created_by=user_id,
    )
    db.add(exam)
    await db.flush()
    total = 0.0
    for qid in payload.question_ids:
        question = await db.get(Question, qid)
        if question and question.status == "PUBLISHED":
            question.exam_id = exam.id
            total += float(question.score or 0)
    exam.total_score = int(total)
    await db.commit()
    await db.refresh(exam)
    return exam


async def force_submit_exam_flow(db: AsyncSession, exam_id: int) -> list[dict]:
    exam = await get_exam(db, exam_id)
    records = (
        await db.execute(
            select(ExamRecord)
            .options(selectinload(ExamRecord.answers))
            .where(ExamRecord.exam_id == exam_id, ExamRecord.status == "IN_PROGRESS")
        )
    ).scalars().all()
    results = []
    for record in records:
        results.append(await grade_saved_answers(db, exam, record, "AUTO_FORCE"))
    return results


async def monitor_switch_flow(db: AsyncSession, record_id: int, user_id: int) -> dict:
    record = (
        await db.execute(
            select(ExamRecord).options(selectinload(ExamRecord.answers)).where(ExamRecord.id == record_id)
        )
    ).scalar_one_or_none()
    if not record or record.user_id != user_id:
        raise HTTPException(404, "考试记录不存在")
    if record.status != "IN_PROGRESS":
        return {"record_id": record.id, "switch_count": record.switch_count, "status": record.status}

    exam = await get_exam(db, record.exam_id)
    record.switch_count = (record.switch_count or 0) + 1
    if record.switch_count > (exam.max_switch_cnt or 3):
        result = await grade_saved_answers(db, exam, record, "AUTO_FORCE")
        return {"record_id": record.id, "switch_count": record.switch_count, "auto_submitted": True, **result}
    await db.commit()
    return {"record_id": record.id, "switch_count": record.switch_count, "auto_submitted": False}
