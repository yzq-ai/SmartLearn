"""到时自动收卷（每 30s 扫描超时记录）。"""
from __future__ import annotations

from datetime import datetime

from sqlalchemy import select

from app.models import ExamRecord
from app.tasks.celery_app import celery_app
from app.tasks.sync_db import SyncSessionLocal


@celery_app.task(name="app.tasks.exam_jobs.auto_collect_expired")
def auto_collect_expired() -> dict:
    """扫描到时未交卷记录，自动收卷并触发异步判分。"""
    db = SyncSessionLocal()
    try:
        now = datetime.utcnow()
        rows = db.execute(
            select(ExamRecord).where(ExamRecord.status == "IN_PROGRESS", ExamRecord.deadline_at < now)
        ).scalars().all()
        from app.tasks.grading_tasks import grade_exam_record
        for record in rows:
            record.status = "EXPIRED"
            record.submit_type = "AUTO_TIME"
            record.submitted_at = now
            grade_exam_record.delay(record.id)
        db.commit()
        return {"collected": len(rows)}
    finally:
        db.close()
