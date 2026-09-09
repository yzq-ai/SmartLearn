"""DEPRECATED: Routes have been split into app.api.v1 per-domain modules. This file is kept for backward compatibility only."""
from __future__ import annotations

from datetime import datetime

from fastapi import APIRouter, Body, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth import current_user, get_optional_user, oauth2_scheme, require_roles
from app.core.response import success
from app.database import get_db
from app.db.redis import acquire_submit_lock
from app.models import (
    ExamAnswer, Resource, WrongQuestion,
)
from app.schemas import (
    CourseCreate,
    ExamAnswersSaveRequest,
    ExamCreate,
    ExamSubmitRequest,
    JobStatusUpdate,
    LoginRequest,
    PasswordChange,
    ProgressUpdate,
    RefreshRequest,
    ResourceCreate,
    ResumeCreate,
)
from app.services.auth_service import (
    cancel_deactivate_flow,
    change_password_flow,
    deactivate_flow,
    login_flow,
    logout_flow,
    register_flow,
    refresh_flow,
)
from app.services.course_service import (
    create_course,
    get_chapter_detail,
    get_course_detail,
    get_progress_list,
    get_section_detail,
    list_courses,
    update_course,
    update_progress,
)
from app.services.exam_engine import (
    answer_from_storage,
    create_exam_flow,
    do_submit,
    force_submit_exam_flow,
    get_exam,
    get_exam_state,
    monitor_switch_flow,
    prepare_open_record,
    record_out,
    save_exam_answers_flow,
    start_exam_record,
)
from app.services.job_service import (
    apply_job_flow,
    favorite_job_flow,
    job_detail_flow,
    list_applications,
    list_favorites,
    list_recommendations,
    unfavorite_job_flow,
    update_application_status_flow,
)
from app.services.notify_service import (
    create_notification,
    list_notifications,
    mark_all_notifications_read,
    mark_notification_read,
    unread_notification_count,
)
from app.services.resume_service import create_resume as create_resume_svc
from app.services.resume_service import list_resumes as list_resumes_svc
from app.core.config import settings

router = APIRouter()
EXAM_DURATION_MINUTES = max(1, int(settings.exam_duration_minutes))


def _wrong_out(row: WrongQuestion) -> dict:
    return {
        "id": row.id,
        "question_id": row.question_id,
        "question_type": row.question.type if row.question else None,
        "question_text": row.question.text if row.question else "",
        "correct_answer": row.question.answer if row.question else "",
        "analysis": row.question.analysis if row.question else "",
        "my_answer": answer_from_storage(row.my_answer) if row.my_answer else None,
        "source_type": row.source_type,
        "wrong_count": row.wrong_count,
        "is_mastered": row.is_mastered,
    }


@router.post("/auth/login", tags=["auth"])
async def login(payload: LoginRequest, db: AsyncSession = Depends(get_db)):
    return success(await login_flow(db, payload.username, payload.password))


@router.post("/auth/register", tags=["auth"])
async def register(payload: LoginRequest, db: AsyncSession = Depends(get_db)):
    return success(await register_flow(db, payload.username, payload.password))


@router.post("/auth/refresh", tags=["auth"])
async def refresh(payload: RefreshRequest, db: AsyncSession = Depends(get_db)):
    return success(await refresh_flow(db, payload.refresh_token))


@router.post("/auth/logout", tags=["auth"])
async def logout(payload: dict | None = Body(default=None), token: str = Depends(oauth2_scheme)):
    refresh_token = (payload or {}).get("refresh_token")
    return success(await logout_flow(token, refresh_token))


@router.put("/auth/password", tags=["auth"])
async def change_password(payload: PasswordChange, db: AsyncSession = Depends(get_db), user=Depends(current_user)):
    return success(await change_password_flow(db, user, payload.old_password, payload.new_password))


@router.post("/users/me/deactivate", tags=["auth"])
async def deactivate(db: AsyncSession = Depends(get_db), user=Depends(current_user)):
    return success(await deactivate_flow(db, user))


@router.post("/users/me/deactivate/cancel", tags=["auth"])
async def cancel_deactivate(db: AsyncSession = Depends(get_db), user=Depends(current_user)):
    return success(await cancel_deactivate_flow(db, user))


@router.get("/courses", tags=["courses"])
async def courses(db: AsyncSession = Depends(get_db)):
    return success(await list_courses(db))


@router.get("/courses/{course_id}", tags=["courses"])
async def course_detail(course_id: int, db: AsyncSession = Depends(get_db)):
    return success(await get_course_detail(db, course_id))


@router.get("/courses/{course_id}/chapters/{chapter_id}", tags=["courses"])
async def chapter_detail(course_id: int, chapter_id: int, db: AsyncSession = Depends(get_db)):
    return success(await get_chapter_detail(db, course_id, chapter_id))


@router.get("/courses/{course_id}/chapters/{chapter_id}/sections/{section_id}", tags=["courses"])
async def section_detail(course_id: int, chapter_id: int, section_id: int, db: AsyncSession = Depends(get_db)):
    return success(await get_section_detail(db, course_id, chapter_id, section_id))


@router.post("/courses", tags=["courses"])
async def create_course_route(payload: CourseCreate, db: AsyncSession = Depends(get_db), user=Depends(require_roles("TEACHER", "ADMIN"))):
    return success(await create_course(db, payload, user))


@router.put("/courses/{course_id}", tags=["courses"])
async def update_course_route(course_id: int, payload: CourseCreate, db: AsyncSession = Depends(get_db), user=Depends(require_roles("TEACHER", "ADMIN"))):
    return success(await update_course(db, course_id, payload))


@router.post("/resources/upload-token", tags=["courses"])
async def resource_upload_token(db: AsyncSession = Depends(get_db), user=Depends(require_roles("TEACHER", "ADMIN"))):
    from app.services.obs import create_upload_token
    return success(create_upload_token())


@router.post("/resources", tags=["courses"])
async def create_resource(payload: ResourceCreate, db: AsyncSession = Depends(get_db), user=Depends(require_roles("TEACHER", "ADMIN"))):
    resource = Resource(
        file_name=payload.file_name,
        file_type=payload.file_type,
        file_size=payload.file_size,
        oss_key=payload.oss_key,
        duration=payload.duration,
        uploader_id=user.id,
        status=1,
    )
    db.add(resource)
    await db.commit()
    await db.refresh(resource)
    return success({"id": resource.id, "file_name": resource.file_name, "oss_key": resource.oss_key})


@router.get("/exams", tags=["exams"])
async def list_exams(db: AsyncSession = Depends(get_db)):
    from app.models import Exam
    rows = (await db.execute(select(Exam))).scalars().all()
    return success([{"id": e.id, "title": e.title, "status": e.status, "duration_min": e.duration_min} for e in rows])


@router.post("/exams", tags=["exams"])
async def create_exam(payload: ExamCreate, db: AsyncSession = Depends(get_db), user=Depends(require_roles("TEACHER", "ADMIN"))):
    exam = await create_exam_flow(db, payload, user.id)
    return success({"id": exam.id, "title": exam.title, "duration_min": exam.duration_min, "total_score": exam.total_score})


@router.get("/exams/{exam_id}", tags=["exams"])
async def exam_detail(exam_id: int, db: AsyncSession = Depends(get_db)):
    exam = await get_exam(db, exam_id)
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
    record = await start_exam_record(db, exam_id, user.id, EXAM_DURATION_MINUTES)
    return success(record_out(record))


@router.get("/exams/{exam_id}/state", tags=["exams"])
async def exam_state(exam_id: int, db: AsyncSession = Depends(get_db), user=Depends(current_user)):
    record = await get_exam_state(db, exam_id, user.id)
    return success(record_out(record))


@router.get("/exams/{exam_id}/monitor", tags=["exams"])
async def exam_monitor(exam_id: int, db: AsyncSession = Depends(get_db), user=Depends(require_roles("TEACHER", "ADMIN"))):
    from app.models import Exam, ExamRecord, User
    await get_exam(db, exam_id)
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
            "started_at": r.started_at, "submitted_at": r.submitted_at,
        }
        for r, u in rows
    ])


@router.get("/records/{record_id}/answers", tags=["exams"])
async def record_answers(record_id: int, db: AsyncSession = Depends(get_db), user=Depends(require_roles("TEACHER", "ADMIN"))):
    from app.models import ExamRecord, ExamAnswer, Question
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
            "answer": answer_from_storage(a.answer), "is_correct": a.is_correct, "score": a.score,
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
    record = await save_exam_answers_flow(db, exam_id, user.id, payload)
    return success(record_out(record))


@router.post("/exams/{exam_id}/submit", tags=["exams"])
async def submit_exam(
    exam_id: int,
    payload: ExamSubmitRequest,
    db: AsyncSession = Depends(get_db),
    user=Depends(current_user),
):
    exam = await get_exam(db, exam_id)
    record = await prepare_open_record(db, exam_id, user.id)

    lock = await acquire_submit_lock(exam_id, user.id)
    if lock is not None:
        try:
            async with lock:
                record = await prepare_open_record(db, exam_id, user.id)
                return success(await do_submit(db, exam, record, payload, exam_id))
        except RuntimeError:
            raise HTTPException(409, "请勿重复提交")
    return success(await do_submit(db, exam, record, payload, exam_id))


@router.post("/records/{record_id}/monitor", tags=["exams"])
async def monitor_record(record_id: int, db: AsyncSession = Depends(get_db), user=Depends(current_user)):
    return success(await monitor_switch_flow(db, record_id, user.id))


@router.post("/exams/{exam_id}/force-submit", tags=["exams"])
async def force_submit_exam(exam_id: int, db: AsyncSession = Depends(get_db), user=Depends(require_roles("TEACHER", "ADMIN"))):
    results = await force_submit_exam_flow(db, exam_id)
    return success({"forced": len(results), "records": results})


@router.get("/notifications", tags=["notify"])
async def list_notifications_route(db: AsyncSession = Depends(get_db), user=Depends(current_user)):
    return success(await list_notifications(db, user))


@router.post("/notifications", tags=["notify"])
async def create_notification_route(payload: dict, db: AsyncSession = Depends(get_db), user=Depends(require_roles("TEACHER", "ADMIN"))):
    return success(await create_notification(db, payload, user.id))


@router.put("/notifications/{notification_id}/read", tags=["notify"])
async def mark_notification_read_route(notification_id: int, db: AsyncSession = Depends(get_db), user=Depends(current_user)):
    return success(await mark_notification_read(db, user.id, notification_id))


@router.put("/notifications/read-all", tags=["notify"])
async def mark_all_notifications_read_route(db: AsyncSession = Depends(get_db), user=Depends(current_user)):
    return success(await mark_all_notifications_read(db, user))


@router.get("/notifications/unread-count", tags=["notify"])
async def unread_notification_count_route(db: AsyncSession = Depends(get_db), user=Depends(current_user)):
    return success(await unread_notification_count(db, user))


@router.get("/progress", tags=["progress"])
async def get_progress(db: AsyncSession = Depends(get_db), user=Depends(current_user)):
    return success(await get_progress_list(db, user.id))


@router.put("/progress/{course_id}", tags=["progress"])
async def update_progress_route(
    course_id: int,
    payload: ProgressUpdate,
    db: AsyncSession = Depends(get_db),
    user=Depends(current_user),
):
    return success(await update_progress(db, user.id, course_id, payload))


@router.get("/jobs/recommendations", tags=["jobs"])
async def recommendations(db: AsyncSession = Depends(get_db), user=Depends(get_optional_user)):
    return success(await list_recommendations(db, user))


@router.post("/jobs/{job_id}/applications", tags=["jobs"])
@router.post("/jobs/{job_id}/apply", tags=["jobs"], include_in_schema=False)
async def apply_job(job_id: int, db: AsyncSession = Depends(get_db), user=Depends(require_roles("STUDENT"))):
    return success(await apply_job_flow(db, user.id, job_id))


@router.get("/jobs/applications", tags=["jobs"])
async def list_applications_route(db: AsyncSession = Depends(get_db), user=Depends(require_roles("STUDENT"))):
    return success(await list_applications(db, user.id))


@router.put("/applications/{application_id}/status", tags=["jobs"])
async def update_application_status(
    application_id: int, payload: JobStatusUpdate, db: AsyncSession = Depends(get_db), user=Depends(require_roles("TEACHER", "ADMIN")),
):
    return success(await update_application_status_flow(db, application_id, payload.status, payload.reject_reason))


@router.put("/jobs/{job_id}/favorite", tags=["jobs"])
async def favorite_job(job_id: int, db: AsyncSession = Depends(get_db), user=Depends(require_roles("STUDENT"))):
    return success(await favorite_job_flow(db, user.id, job_id))


@router.delete("/jobs/{job_id}/favorite", tags=["jobs"])
async def unfavorite_job(job_id: int, db: AsyncSession = Depends(get_db), user=Depends(require_roles("STUDENT"))):
    return success(await unfavorite_job_flow(db, user.id, job_id))


@router.get("/jobs/favorites", tags=["jobs"])
async def list_favorites_route(db: AsyncSession = Depends(get_db), user=Depends(require_roles("STUDENT"))):
    return success(await list_favorites(db, user))


@router.get("/jobs/{job_id}", tags=["jobs"])
async def job_detail(job_id: int, db: AsyncSession = Depends(get_db), user=Depends(current_user)):
    return success(await job_detail_flow(db, user.id, job_id))


@router.get("/wrong-questions", tags=["wrong"])
async def list_wrong_questions(db: AsyncSession = Depends(get_db), user=Depends(current_user)):
    from sqlalchemy.orm import selectinload
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


@router.get("/profile/me", tags=["profile"])
async def get_profile(db: AsyncSession = Depends(get_db), user=Depends(require_roles("STUDENT"))):
    from app.models import StudentProfile
    from app.services.assessment_service import refresh_profile
    profile = await db.scalar(select(StudentProfile).where(StudentProfile.user_id == user.id))
    if not profile:
        profile = await refresh_profile(db, user.id)
        await db.commit()
    return success({
        "user_id": profile.user_id,
        "skill_scores": profile.skill_scores or {},
        "radar_data": profile.radar_data or {},
        "self_tags": profile.self_tags or [],
        "match_version": profile.match_version,
    })


@router.post("/profile/refresh", tags=["profile"])
async def refresh_student_profile(db: AsyncSession = Depends(get_db), user=Depends(require_roles("STUDENT"))):
    from app.services.assessment_service import refresh_profile
    profile = await refresh_profile(db, user.id)
    await db.commit()
    return success({
        "user_id": profile.user_id,
        "skill_scores": profile.skill_scores or {},
        "radar_data": profile.radar_data or {},
        "match_version": profile.match_version,
    })


@router.get("/resumes", tags=["resumes"])
async def list_resumes(db: AsyncSession = Depends(get_db), user=Depends(require_roles("STUDENT"))):
    return success(await list_resumes_svc(db, user.id))


@router.post("/resumes", tags=["resumes"])
async def create_resume(payload: ResumeCreate, db: AsyncSession = Depends(get_db), user=Depends(require_roles("STUDENT"))):
    return success(await create_resume_svc(db, user.id, payload))
