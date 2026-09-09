"""Celery 异步任务：日统计聚合、到时自动收卷、画像重算。"""
from __future__ import annotations

from datetime import date, datetime

from sqlalchemy import select

from app.models import (
    Course, Exam, ExamRecord, KnowledgePoint, StatDailyLearning,
    StudentKpMastery, StudentProfile, User,
)
from app.services.mastery_service import build_radar_data, build_skill_scores
from app.tasks.celery_app import celery_app
from app.tasks.sync_db import SyncSessionLocal


@celery_app.task(name="app.tasks.jobs.aggregate_daily_stats")
def aggregate_daily_stats() -> dict:
    """每日聚合：把课程/考试/答题量写入 stat_daily_learning 宽表。"""
    db = SyncSessionLocal()
    try:
        today = date.today()
        courses = db.execute(select(Course)).scalars().all()
        for course in courses:
            exam_count = len(db.execute(select(Exam.id).where(Exam.course_id == course.id)).scalars().all())
            record_count = len(
                db.execute(
                    select(ExamRecord.id).join(Exam, ExamRecord.exam_id == Exam.id).where(Exam.course_id == course.id)
                ).scalars().all()
            )
            metrics = {"student_count": course.student_count, "exam_count": exam_count, "record_count": record_count}
            row = db.execute(
                select(StatDailyLearning).where(
                    StatDailyLearning.scope_type == "COURSE",
                    StatDailyLearning.scope_id == course.id,
                    StatDailyLearning.stat_date == today,
                )
            ).scalar_one_or_none()
            if row:
                row.metrics = metrics
            else:
                db.add(StatDailyLearning(scope_type="COURSE", scope_id=course.id, stat_date=today, metrics=metrics))
        db.commit()
        return {"courses": len(courses)}
    finally:
        db.close()


@celery_app.task(name="app.tasks.jobs.auto_collect_exams")
def auto_collect_exams() -> dict:
    """扫描到时未交卷记录，自动收卷（服务端兜底）。"""
    db = SyncSessionLocal()
    try:
        now = datetime.utcnow()
        rows = db.execute(
            select(ExamRecord).where(ExamRecord.status == "IN_PROGRESS", ExamRecord.deadline_at < now)
        ).scalars().all()
        for record in rows:
            record.status = "EXPIRED"
            record.submit_type = "AUTO_TIME"
            record.submitted_at = now
        db.commit()
        return {"collected": len(rows)}
    finally:
        db.close()


@celery_app.task(name="app.tasks.jobs.refresh_profile")
def refresh_profile(user_id: int) -> dict:
    """基于知识点掌握度重建技能分与六维雷达（同步 worker 版）。"""
    db = SyncSessionLocal()
    try:
        mastery_rows = db.execute(
            select(StudentKpMastery).where(StudentKpMastery.user_id == user_id)
        ).scalars().all()
        kp_ids = [m.kp_id for m in mastery_rows]
        kp_names: dict[int, str] = {}
        if kp_ids:
            kps = db.execute(select(KnowledgePoint).where(KnowledgePoint.id.in_(kp_ids))).scalars().all()
            kp_names = {k.id: k.name for k in kps}

        skill_scores = build_skill_scores(
            [{"kp_id": m.kp_id, "correct_cnt": m.correct_cnt, "total_cnt": m.total_cnt} for m in mastery_rows],
            kp_names,
        )
        profile = db.execute(select(StudentProfile).where(StudentProfile.user_id == user_id)).scalar_one_or_none()
        if not profile:
            profile = StudentProfile(user_id=user_id)
            db.add(profile)
        profile.skill_scores = skill_scores
        profile.radar_data = build_radar_data(skill_scores)
        profile.match_version = (profile.match_version or 0) + 1
        profile.updated_at = datetime.utcnow()
        db.commit()
        return {"user_id": user_id, "skill_scores": skill_scores}
    finally:
        db.close()


@celery_app.task(name="app.tasks.jobs.purge_deactivated_users")
def purge_deactivated_users() -> dict:
    """注销冷静期到期后物理删除用户（7 天）。"""
    db = SyncSessionLocal()
    try:
        now = datetime.utcnow()
        rows = db.execute(select(User).where(User.deleted_at < now)).scalars().all()
        for user in rows:
            db.delete(user)
        db.commit()
        return {"purged": len(rows)}
    finally:
        db.close()
