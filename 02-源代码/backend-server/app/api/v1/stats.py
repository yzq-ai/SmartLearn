from __future__ import annotations

from fastapi import APIRouter, Depends
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth import require_roles
from app.core.response import success
from app.database import get_db
from app.models import Course, CourseEnrollment, Exam, ExamAnswer, ExamRecord, Question, WrongQuestion

router = APIRouter()


@router.get("/stats/learning", tags=["stats"])
async def learning_stats(db: AsyncSession = Depends(get_db), user=Depends(require_roles("TEACHER", "ADMIN"))):
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

    # 高频错题：按累计答错次数（wrong_count 权重）聚合
    wrong_rows = (
        await db.execute(
            select(Question.id, Question.text, func.sum(WrongQuestion.wrong_count).label("cnt"))
            .join(WrongQuestion, WrongQuestion.question_id == Question.id)
            .group_by(Question.id, Question.text)
            .order_by(func.sum(WrongQuestion.wrong_count).desc())
            .limit(10)
        )
    ).all()

    # 考试参与 + 真实平均分（按卷面归一化到百分制）
    exam_rows = (
        await db.execute(
            select(
                Exam.id, Exam.title,
                func.count(func.distinct(ExamRecord.user_id)).label("records"),
                func.avg(ExamRecord.score).label("avg_raw"),
                func.avg(ExamRecord.score * 100.0 / func.nullif(ExamRecord.total, 0)).label("avg_pct"),
                func.count(ExamRecord.id).label("graded"),
            )
            .outerjoin(ExamRecord, ExamRecord.exam_id == Exam.id)
            .group_by(Exam.id, Exam.title)
        )
    ).all()

    # 全库真实平均分（百分制）：所有已交卷记录归一化后平均
    overall_avg = (
        await db.execute(
            select(func.avg(ExamRecord.score * 100.0 / func.nullif(ExamRecord.total, 0)))
        )
    ).scalar()

    # 题型正确率（雷达图真实数据）：按题型聚合每题得分率 ExamAnswer.score/Question.score
    type_rows = (
        await db.execute(
            select(Question.type, func.avg(ExamAnswer.score * 100.0 / func.nullif(Question.score, 0)).label("rate"))
            .join(ExamAnswer, ExamAnswer.question_id == Question.id)
            .where(ExamAnswer.score.isnot(None), Question.score > 0)
            .group_by(Question.type)
        )
    ).all()

    return success({
        "courses": course_rows,
        "top_wrong": [{"question_id": r[0], "text": r[1], "count": int(r[2] or 0)} for r in wrong_rows],
        "exams": [
            {
                "id": r[0], "title": r[1], "records": int(r[2] or 0),
                "avg_score": round(float(r[4]), 1) if r[4] is not None else None,
                "avg_raw": round(float(r[3]), 1) if r[3] is not None else None,
                "graded": int(r[5] or 0),
            }
            for r in exam_rows
        ],
        "overall_avg_score": round(float(overall_avg), 1) if overall_avg is not None else None,
        "type_rates": {r[0]: round(float(r[1] or 0), 1) for r in type_rows},
    })
