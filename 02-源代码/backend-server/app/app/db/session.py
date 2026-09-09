"""Backward-compatible re-export of the canonical database module.

Prefer importing from ``app.database``; this module exists for older callers.
"""
from app.database import Base, SessionLocal, engine, get_db, init_db

AsyncSessionLocal = SessionLocal

__all__ = ["Base", "engine", "SessionLocal", "AsyncSessionLocal", "get_db", "init_db"]
