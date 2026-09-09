"""截止/开考提醒推送。"""
from __future__ import annotations

import logging

from app.tasks.celery_app import celery_app

logger = logging.getLogger(__name__)


@celery_app.task(name="app.tasks.notify_jobs.send_exam_reminder")
def send_exam_reminder(exam_id: int, minutes_before: int = 60) -> dict:
    logger.info("Exam reminder: exam_id=%d, %d min before", exam_id, minutes_before)
    return {"exam_id": exam_id, "sent": True}


@celery_app.task(name="app.tasks.notify_jobs.send_assignment_deadline")
def send_assignment_deadline(assignment_id: int) -> dict:
    logger.info("Assignment deadline reminder: assignment_id=%d", assignment_id)
    return {"assignment_id": assignment_id, "sent": True}
