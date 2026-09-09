from __future__ import annotations

from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth import current_user, require_roles
from app.core.response import success
from app.database import get_db
from app.models import Assignment, AssignmentSubmission, Course, User
from app.schemas import AssignmentCreate, AssignmentSubmit, GradeSubmission

router = APIRouter()


@router.post("/assignments", tags=["assignments"])
async def create_assignment(payload: AssignmentCreate, db: AsyncSession = Depends(get_db), user=Depends(require_roles("TEACHER", "ADMIN"))):
    if not await db.get(Course, payload.course_id):
        raise HTTPException(404, "课程不存在")
    assignment = Assignment(
        course_id=payload.course_id,
        title=payload.title,
        description=payload.description,
        max_score=payload.max_score,
        deadline=payload.deadline,
        created_by=user.id,
    )
    db.add(assignment)
    await db.commit()
    await db.refresh(assignment)
    return success({
        "id": assignment.id,
        "course_id": assignment.course_id,
        "title": assignment.title,
        "description": assignment.description,
        "max_score": assignment.max_score,
        "deadline": assignment.deadline,
    })


@router.get("/assignments", tags=["assignments"])
async def list_assignments(course_id: int | None = None, db: AsyncSession = Depends(get_db), user=Depends(current_user)):
    statement = select(Assignment).order_by(Assignment.deadline)
    if course_id is not None:
        statement = statement.where(Assignment.course_id == course_id)
    rows = (await db.execute(statement)).scalars().all()

    my_subs: dict[int, AssignmentSubmission] = {}
    if user.role == "STUDENT":
        if rows:
            subs = (
                await db.execute(
                    select(AssignmentSubmission).where(
                        AssignmentSubmission.student_id == user.id,
                        AssignmentSubmission.assignment_id.in_([a.id for a in rows]),
                    )
                )
            ).scalars().all()
            my_subs = {s.assignment_id: s for s in subs}

    now = datetime.utcnow()
    return success([
        {
            "id": a.id,
            "course_id": a.course_id,
            "title": a.title,
            "description": a.description,
            "max_score": a.max_score,
            "deadline": a.deadline,
            "is_expired": now > a.deadline,
            "my_submission": {
                "id": my_subs[a.id].id,
                "status": my_subs[a.id].status,
                "score": my_subs[a.id].score,
                "feedback": my_subs[a.id].feedback,
                "is_late": my_subs[a.id].is_late,
                "submitted_at": my_subs[a.id].submitted_at,
                "content": my_subs[a.id].content,
            } if a.id in my_subs else None,
        }
        for a in rows
    ])


@router.post("/assignments/{assignment_id}/submit", tags=["assignments"])
async def submit_assignment(
    assignment_id: int,
    payload: AssignmentSubmit,
    db: AsyncSession = Depends(get_db),
    user=Depends(require_roles("STUDENT")),
):
    assignment = await db.get(Assignment, assignment_id)
    if not assignment:
        raise HTTPException(404, "作业不存在")
    now = datetime.utcnow()
    is_late = 1 if now > assignment.deadline else 0

    sub = (
        await db.execute(
            select(AssignmentSubmission).where(
                AssignmentSubmission.assignment_id == assignment_id,
                AssignmentSubmission.student_id == user.id,
            )
        )
    ).scalar_one_or_none()

    if sub:
        if sub.status == "GRADED":
            raise HTTPException(409, "作业已批改，如需修改请联系教师退回重做")
        sub.content = payload.content
        sub.resource_ids = payload.resource_ids
        sub.submitted_at = now
        sub.is_late = is_late
        sub.version = (sub.version or 1) + 1
        sub.status = "SUBMITTED"
    else:
        sub = AssignmentSubmission(
            assignment_id=assignment_id,
            student_id=user.id,
            content=payload.content,
            resource_ids=payload.resource_ids,
            submitted_at=now,
            is_late=is_late,
            status="SUBMITTED",
            version=1,
        )
        db.add(sub)
    await db.commit()
    await db.refresh(sub)
    return success({
        "id": sub.id,
        "assignment_id": sub.assignment_id,
        "status": sub.status,
        "is_late": sub.is_late,
        "version": sub.version,
    })


@router.post("/assignments/{assignment_id}/remind", tags=["assignments"])
async def remind_assignment(assignment_id: int, db: AsyncSession = Depends(get_db), user=Depends(require_roles("TEACHER", "ADMIN"))):
    assignment = await db.get(Assignment, assignment_id)
    if not assignment:
        raise HTTPException(404, "作业不存在")
    submitted_ids = set(
        (await db.execute(select(AssignmentSubmission.student_id).where(AssignmentSubmission.assignment_id == assignment_id))).scalars().all()
    )
    return success({"assignment_id": assignment_id, "submitted": len(submitted_ids), "message": "已催交未提交学生"})


@router.get("/assignments/{assignment_id}/submissions", tags=["assignments"])
async def list_submissions(assignment_id: int, db: AsyncSession = Depends(get_db), user=Depends(require_roles("TEACHER", "ADMIN"))):
    assignment = await db.get(Assignment, assignment_id)
    if not assignment:
        raise HTTPException(404, "作业不存在")
    rows = (
        await db.execute(
            select(AssignmentSubmission, User)
            .join(User, User.id == AssignmentSubmission.student_id)
            .where(AssignmentSubmission.assignment_id == assignment_id)
            .order_by(AssignmentSubmission.submitted_at)
        )
    ).all()
    return success([
        {
            "id": sub.id,
            "student_id": sub.student_id,
            "username": usr.username,
            "real_name": usr.real_name,
            "content": sub.content,
            "is_late": sub.is_late,
            "score": sub.score,
            "feedback": sub.feedback,
            "status": sub.status,
            "submitted_at": sub.submitted_at,
        }
        for sub, usr in rows
    ])


@router.post("/submissions/{submission_id}/grade", tags=["assignments"])
async def grade_submission(submission_id: int, payload: GradeSubmission, db: AsyncSession = Depends(get_db), user=Depends(require_roles("TEACHER", "ADMIN"))):
    sub = await db.get(AssignmentSubmission, submission_id)
    if not sub:
        raise HTTPException(404, "提交不存在")
    sub.score = payload.score
    sub.feedback = payload.feedback
    sub.graded_by = user.id
    sub.graded_at = datetime.utcnow()
    sub.status = "RETURNED" if payload.return_for_redo else "GRADED"
    await db.commit()
    await db.refresh(sub)
    return success({"id": sub.id, "status": sub.status, "score": sub.score, "feedback": sub.feedback})
