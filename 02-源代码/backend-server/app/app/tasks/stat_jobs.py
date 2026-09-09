"""每日 02:00 统计聚合。"""
from __future__ import annotations

from app.tasks.celery_app import celery_app


@celery_app.task(name="app.tasks.stat_jobs.aggregate_daily")
def aggregate_daily() -> dict:
    from app.tasks.jobs import aggregate_daily_stats
    return aggregate_daily_stats()


@celery_app.task(name="app.tasks.stat_jobs.purge_old_drafts")
def purge_old_drafts() -> dict:
    """清理 30 天未处理的 AI 草稿题。"""
    from datetime import datetime, timedelta

    from sqlalchemy import select, delete

    from app.models import Question
    from app.tasks.sync_db import SyncSessionLocal

    db = SyncSessionLocal()
    try:
        cutoff = datetime.utcnow() - timedelta(days=30)
        result = db.execute(delete(Question).where(Question.status == "DRAFT", Question.created_at < cutoff))
        db.commit()
        return {"purged": result.rowcount}
    finally:
        db.close()
