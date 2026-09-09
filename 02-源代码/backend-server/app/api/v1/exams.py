from __future__ import annotations

import json
from datetime import datetime, timedelta

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.auth import current_user, require_roles
from app.core.config import settings
from app.core.response import success
from app.database import get_db
from app.db.redis import acquire_submit_lock
from app.models import Exam, ExamAnswer, ExamPaperQuestion, ExamRecord, Question, User
from app.schemas import ExamAnswersSaveRequest, ExamCreate, ExamSubmitRequest
from app.services import grade_exam, grade_question
from app.services.assessment_service import apply_exam_results

router = APIRouter()
EXAM_DURATION_MINUTES = max(1, int(settings.exam_duration_minutes))


def _answer_to_storage(answer: str | list[str]) -> str:
    return json.dumps(answer, ensure_ascii=False, separators=(",", ":"))


def _utc_iso(value) -> str | None:
    """naive UTC datetime → 带 Z 的 ISO 串（前端 new Date() 按 UTC 解析，跨时区正确）。"""
    if value is None:
        return None
    return value.strftime("%Y-%m-%dT%H:%M:%S.%f") + "Z"


def _answer_from_storage(answer: str):
    try:
        return json.loads(answer)
    except (TypeError, json.JSONDecodeError):
        return answer


def _record_out(record: ExamRecord, *, review: list[dict] | None = None) -> dict:
    out = {
        "record_id": record.id,
        "exam_id": record.exam_id,
        "status": record.status,
        "started_at": _utc_iso(record.started_at),
        "deadline_at": _utc_iso(record.deadline_at),
        "submitted_at": _utc_iso(record.submitted_at),
        "score": record.score,
        "total": record.total,
        "passed": record.passed,
        "answers": [
            {"question_id": answer.question_id, "answer": _answer_from_storage(answer.answer)}
            for answer in sorted(record.answers, key=lambda item: item.question_id)
        ],
    }
    # 交卷后附每题解析（题干/我的答案/正确答案/得分/解析），支持“全部答完再给答案”
    if record.status in ("SUBMITTED", "GRADING", "GRADED") and review is not None:
        out["review"] = review
    return out


async def _build_review(db: AsyncSession, record: ExamRecord) -> list[dict]:
    """组装逐题复盘数据：题干、选项、我的答案、正确答案、是否正确、得分、解析。"""
    exam_q = (
        await db.execute(
            select(Question)
            .join(ExamPaperQuestion, ExamPaperQuestion.question_id == Question.id)
            .where(ExamPaperQuestion.paper_id == record.exam_id)
        )
    ).scalars().all()
    if not exam_q:
        # 兼容 question.exam_id 直接挂考试（种子数据的关联方式）
        exam_q = (
            await db.execute(select(Question).where(Question.exam_id == record.exam_id))
        ).scalars().all()
    my_answers = {a.question_id: _answer_from_storage(a.answer) for a in record.answers}
    review: list[dict] = []
    for q in exam_q:
        mine = my_answers.get(q.id)
        mine_str = mine if isinstance(mine, str) else (",".join(str(x) for x in mine) if mine else "")
        earned = grade_question(q.type, mine, q.answer, float(q.score or 0))
        review.append({
            "question_id": q.id,
            "type": q.type,
            "text": q.text,
            "options": q.options or [],
            "my_answer": mine_str,
            "correct_answer": q.answer,
            "earned": earned if earned is not None else None,
            "score": float(q.score or 0),
            "analysis": q.analysis or "",
        })
    return review


async def _get_exam(db: AsyncSession, exam_id: int) -> Exam:
    exam = (
        await db.execute(
            select(Exam).options(selectinload(Exam.questions)).where(Exam.id == exam_id)
        )
    ).scalar_one_or_none()
    if not exam:
        raise HTTPException(404, "考试不存在")
    return exam


async def _get_record(db: AsyncSession, exam_id: int, user_id: int, *, lock: bool = False) -> ExamRecord | None:
    statement = (
        select(ExamRecord)
        .options(selectinload(ExamRecord.answers))
        .where(ExamRecord.exam_id == exam_id, ExamRecord.user_id == user_id)
    )
    if lock:
        statement = statement.with_for_update()
    return (await db.execute(statement)).scalar_one_or_none()


def _ensure_open(record: ExamRecord, now: datetime) -> None:
    if record.status == "SUBMITTED":
        raise HTTPException(409, "考试已提交，请勿重复提交")
    if record.status == "EXPIRED" or now >= record.deadline_at:
        record.status = "EXPIRED"
        raise HTTPException(409, "考试已截止")


def _validate_answers(exam: Exam, answers) -> None:
    valid_ids = {question.id for question in exam.questions}
    submitted_ids = [answer.question_id for answer in answers]
    if len(submitted_ids) != len(set(submitted_ids)):
        raise HTTPException(422, "答案中包含重复题目")
    invalid_ids = sorted(set(submitted_ids) - valid_ids)
    if invalid_ids:
        raise HTTPException(422, f"答案包含不属于本考试的题目: {invalid_ids}")


async def _save_answers(db: AsyncSession, record: ExamRecord, answers) -> None:
    existing = {answer.question_id: answer for answer in record.answers}
    for incoming in answers:
        stored = _answer_to_storage(incoming.answer)
        if incoming.question_id in existing:
            existing[incoming.question_id].answer = stored
            existing[incoming.question_id].updated_at = datetime.utcnow()
        else:
            answer = ExamAnswer(record_id=record.id, question_id=incoming.question_id, answer=stored)
            db.add(answer)
            record.answers.append(answer)


async def _prepare_open_record(db: AsyncSession, exam_id: int, user_id: int) -> ExamRecord:
    record = await _get_record(db, exam_id, user_id, lock=True)
    if not record:
        raise HTTPException(409, "请先开始考试")
    try:
        _ensure_open(record, datetime.utcnow())
    except HTTPException:
        await db.commit()
        raise
    return record


async def _do_submit(db: AsyncSession, exam: Exam, record: ExamRecord, payload: ExamSubmitRequest, exam_id: int) -> dict:
    _validate_answers(exam, payload.answers)
    await _save_answers(db, record, payload.answers)

    answer_map = {answer.question_id: _answer_from_storage(answer.answer) for answer in record.answers}
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


async def _grade_saved_answers(db: AsyncSession, exam: Exam, record: ExamRecord, submit_type: str) -> dict:
    answer_map = {answer.question_id: _answer_from_storage(answer.answer) for answer in record.answers}
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


@router.get("/exams", tags=["exams"])
async def list_exams(db: AsyncSession = Depends(get_db)):
    rows = (await db.execute(select(Exam))).scalars().all()

    def _phase(e) -> str:
        """PUBLISHED 视角下按时间推导：ended / ongoing / upcoming / open。"""
        if e.status == 2:
            return "ended"
        if e.start_time is not None and e.end_time is not None:
            from datetime import datetime

            now = datetime.utcnow()
            if now >= e.end_time:
                return "ended"
            if now >= e.start_time:
                return "ongoing"
            return "upcoming"
        return "open"

    return success([
        {
            "id": e.id, "title": e.title, "status": e.status, "duration_min": e.duration_min,
            "course_id": e.course_id, "start_time": e.start_time, "end_time": e.end_time,
            "phase": _phase(e),
        }
        for e in rows
    ])


@router.post("/exams", tags=["exams"])
async def create_exam(payload: ExamCreate, db: AsyncSession = Depends(get_db), user=Depends(require_roles("TEACHER", "ADMIN"))):
    exam = Exam(title=payload.title, course_id=payload.course_id, duration_min=payload.duration_min, pass_score=payload.pass_score, created_by=user.id)
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
    return success({"id": exam.id, "title": exam.title, "duration_min": exam.duration_min, "total_score": exam.total_score})


@router.get("/exams/{exam_id}", tags=["exams"])
async def exam_detail(exam_id: int, db: AsyncSession = Depends(get_db)):
    exam = await _get_exam(db, exam_id)
    return success({
        "id": exam.id,
        "title": exam.title,
        "questions": [
            {
                "id": question.id,
                "type": question.type,
                "text": question.text,
                "score": question.score,
                "options": question.options or [],
            }
            for question in exam.questions
        ],
    })


@router.post("/exams/{exam_id}/start", tags=["exams"])
async def start_exam(exam_id: int, db: AsyncSession = Depends(get_db), user=Depends(current_user)):
    await _get_exam(db, exam_id)
    record = await _get_record(db, exam_id, user.id)
    if record:
        if record.status == "SUBMITTED":
            raise HTTPException(409, "考试已提交，不能重复开始")
        if datetime.utcnow() >= record.deadline_at:
            record.status = "EXPIRED"
            await db.commit()
            raise HTTPException(409, "考试已截止")
        return success(_record_out(record))

    now = datetime.utcnow()
    record = ExamRecord(
        user_id=user.id,
        exam_id=exam_id,
        status="IN_PROGRESS",
        started_at=now,
        deadline_at=now + timedelta(minutes=EXAM_DURATION_MINUTES),
    )
    db.add(record)
    try:
        await db.commit()
    except IntegrityError:
        await db.rollback()
        record = await _get_record(db, exam_id, user.id)
        if not record:
            raise
    await db.refresh(record, attribute_names=["answers"])
    return success(_record_out(record))


@router.get("/exams/{exam_id}/state", tags=["exams"])
async def exam_state(exam_id: int, db: AsyncSession = Depends(get_db), user=Depends(current_user)):
    await _get_exam(db, exam_id)
    record = await _get_record(db, exam_id, user.id)
    if not record:
        raise HTTPException(404, "尚未开始考试")
    if record.status == "IN_PROGRESS" and datetime.utcnow() >= record.deadline_at:
        record.status = "EXPIRED"
        await db.commit()
    review = None
    if record.status in ("SUBMITTED", "GRADING", "GRADED"):
        review = await _build_review(db, record)
    return success(_record_out(record, review=review))


@router.get("/exams/{exam_id}/monitor", tags=["exams"])
async def exam_monitor(exam_id: int, db: AsyncSession = Depends(get_db), user=Depends(require_roles("TEACHER", "ADMIN"))):
    await _get_exam(db, exam_id)
    rows = (
        await db.execute(
            select(ExamRecord, User)
            .join(User, User.id == ExamRecord.user_id)
            .where(ExamRecord.exam_id == exam_id)
            .order_by(ExamRecord.started_at)
        )
    ).all()
    return success([
        {
            "record_id": r.id, "student_id": r.user_id, "username": u.username, "real_name": u.real_name,
            "status": r.status, "switch_count": r.switch_count, "score": r.score, "total": r.total,
            "started_at": _utc_iso(r.started_at), "submitted_at": _utc_iso(r.submitted_at),
        }
        for r, u in rows
    ])


@router.get("/records/{record_id}/answers", tags=["exams"])
async def record_answers(record_id: int, db: AsyncSession = Depends(get_db), user=Depends(require_roles("TEACHER", "ADMIN"))):
    record = await db.get(ExamRecord, record_id)
    if not record:
        raise HTTPException(404, "考试记录不存在")
    rows = (
        await db.execute(
            select(ExamAnswer, Question)
            .join(Question, Question.id == ExamAnswer.question_id)
            .where(ExamAnswer.record_id == record_id)
            .order_by(ExamAnswer.question_id)
        )
    ).all()
    return success([
        {
            "answer_id": a.id, "question_id": a.question_id, "type": q.type, "text": q.text,
            "answer": _answer_from_storage(a.answer), "is_correct": a.is_correct, "score": a.score,
            "teacher_comment": a.teacher_comment,
        }
        for a, q in rows
    ])


@router.post("/answers/{answer_id}/grade", tags=["exams"])
async def grade_answer(answer_id: int, payload: dict, db: AsyncSession = Depends(get_db), user=Depends(require_roles("TEACHER", "ADMIN"))):
    answer = await db.get(ExamAnswer, answer_id)
    if not answer:
        raise HTTPException(404, "答案不存在")
    answer.score = payload.get("score", 0)
    answer.teacher_comment = payload.get("comment")
    answer.is_correct = 1 if (payload.get("score", 0) or 0) > 0 else 0
    await db.commit()
    return success({"answer_id": answer.id, "score": answer.score, "teacher_comment": answer.teacher_comment})


@router.put("/exams/{exam_id}/answers", tags=["exams"])
async def save_exam_answers(
    exam_id: int,
    payload: ExamAnswersSaveRequest,
    db: AsyncSession = Depends(get_db),
    user=Depends(current_user),
):
    exam = await _get_exam(db, exam_id)
    record = await _get_record(db, exam_id, user.id, lock=True)
    if not record:
        raise HTTPException(409, "请先开始考试")
    try:
        _ensure_open(record, datetime.utcnow())
    except HTTPException:
        await db.commit()
        raise
    _validate_answers(exam, payload.answers)
    await _save_answers(db, record, payload.answers)
    await db.commit()
    record = await _get_record(db, exam_id, user.id)
    return success(_record_out(record))


@router.post("/exams/{exam_id}/submit", tags=["exams"])
async def submit_exam(
    exam_id: int,
    payload: ExamSubmitRequest,
    db: AsyncSession = Depends(get_db),
    user=Depends(current_user),
):
    exam = await _get_exam(db, exam_id)
    record = await _prepare_open_record(db, exam_id, user.id)

    lock = await acquire_submit_lock(exam_id, user.id)
    if lock is not None:
        try:
            async with lock:
                record = await _prepare_open_record(db, exam_id, user.id)
                return success(await _do_submit(db, exam, record, payload, exam_id))
        except RuntimeError:
            raise HTTPException(409, "请勿重复提交")
    return success(await _do_submit(db, exam, record, payload, exam_id))


@router.post("/records/{record_id}/monitor", tags=["exams"])
async def monitor_record(record_id: int, db: AsyncSession = Depends(get_db), user=Depends(current_user)):
    record = (
        await db.execute(
            select(ExamRecord).options(selectinload(ExamRecord.answers)).where(ExamRecord.id == record_id)
        )
    ).scalar_one_or_none()
    if not record or record.user_id != user.id:
        raise HTTPException(404, "考试记录不存在")
    if record.status != "IN_PROGRESS":
        return success({"record_id": record.id, "switch_count": record.switch_count, "status": record.status})

    exam = await _get_exam(db, record.exam_id)
    record.switch_count = (record.switch_count or 0) + 1
    if record.switch_count > (exam.max_switch_cnt or 3):
        result = await _grade_saved_answers(db, exam, record, "AUTO_FORCE")
        return success({"record_id": record.id, "switch_count": record.switch_count, "auto_submitted": True, **result})
    await db.commit()
    return success({"record_id": record.id, "switch_count": record.switch_count, "auto_submitted": False})


@router.post("/exams/{exam_id}/force-submit", tags=["exams"])
async def force_submit_exam(exam_id: int, db: AsyncSession = Depends(get_db), user=Depends(require_roles("TEACHER", "ADMIN"))):
    exam = await _get_exam(db, exam_id)
    records = (
        await db.execute(
            select(ExamRecord).options(selectinload(ExamRecord.answers)).where(ExamRecord.exam_id == exam_id, ExamRecord.status == "IN_PROGRESS")
        )
    ).scalars().all()
    results = []
    for record in records:
        results.append(await _grade_saved_answers(db, exam, record, "AUTO_FORCE"))
    return success({"forced": len(results), "records": results})
