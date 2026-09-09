"""PDF/Excel 异步生成。"""
from __future__ import annotations

import logging

from app.tasks.celery_app import celery_app

logger = logging.getLogger(__name__)


@celery_app.task(name="app.tasks.export_jobs.export_resume_pdf")
def export_resume_pdf(resume_id: int) -> dict:
    logger.info("Exporting resume PDF: resume_id=%d", resume_id)
    return {"resume_id": resume_id, "status": "completed"}


@celery_app.task(name="app.tasks.export_jobs.export_stats_excel")
def export_stats_excel(scope_type: str, scope_id: int | None = None) -> dict:
    logger.info("Exporting stats Excel: scope=%s id=%s", scope_type, scope_id)
    return {"scope_type": scope_type, "scope_id": scope_id, "status": "completed"}
