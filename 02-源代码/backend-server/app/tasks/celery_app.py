"""Celery 应用与 Beat 调度。

- 默认 broker 为 ``memory://`` 且 ``task_always_eager=True``，便于本地/测试直跑；
- 生产设 ``CELERY_BROKER_URL`` / ``CELERY_BACKEND_URL`` 为 Redis 并把 eager 置 false。
"""
from __future__ import annotations

from celery import Celery
from celery.schedules import crontab

from app.core.config import settings

celery_app = Celery(
    "smartlearn",
    broker=settings.celery_broker_url,
    backend=settings.celery_backend_url,
    include=[
        "app.tasks.jobs",
        "app.tasks.grading_tasks",
        "app.tasks.exam_jobs",
        "app.tasks.notify_jobs",
        "app.tasks.stat_jobs",
        "app.tasks.kb_jobs",
        "app.tasks.export_jobs",
    ],
)

celery_app.conf.update(
    task_always_eager=settings.celery_always_eager,
    task_eager_propagates=False,
    timezone="Asia/Shanghai",
    enable_utc=False,
)

celery_app.conf.beat_schedule = {
    "auto-collect-expired": {
        "task": "app.tasks.exam_jobs.auto_collect_expired",
        "schedule": 30.0,
    },
    "aggregate-daily": {
        "task": "app.tasks.stat_jobs.aggregate_daily",
        "schedule": crontab(hour=2, minute=0),
    },
    "purge-old-drafts": {
        "task": "app.tasks.stat_jobs.purge_old_drafts",
        "schedule": crontab(hour=3, minute=0),
    },
    "auto-collect-exams-every-30s": {
        "task": "app.tasks.jobs.auto_collect_exams",
        "schedule": 30.0,
    },
    "aggregate-daily-stats-at-2am": {
        "task": "app.tasks.jobs.aggregate_daily_stats",
        "schedule": crontab(hour=2, minute=0),
    },
    "purge-deactivated-users-daily": {
        "task": "app.tasks.jobs.purge_deactivated_users",
        "schedule": crontab(hour=3, minute=0),
    },
}
