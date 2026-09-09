"""Celery worker 用的同步 SQLAlchemy 会话。

FastAPI 层是 async ORM；Celery worker 是同步进程，用同一套模型 + 同步驱动访问同一库。
"""
from __future__ import annotations

from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.core.config import settings

sync_engine = create_engine(settings.sync_database_url, future=True, pool_pre_ping=True)
SyncSessionLocal = sessionmaker(bind=sync_engine, expire_on_commit=False, autoflush=False)
