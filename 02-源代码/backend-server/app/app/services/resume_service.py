"""Resume operations: CRUD, versioning, PDF export trigger.

All DB-mutating functions accept an AsyncSession for dependency injection.
"""
from __future__ import annotations

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import Resume


async def list_resumes(db: AsyncSession, user_id: int) -> list[dict]:
    rows = (
        await db.execute(select(Resume).where(Resume.user_id == user_id).order_by(Resume.updated_at.desc()))
    ).scalars().all()
    return [
        {"id": r.id, "title": r.title, "content": r.content, "version": r.version, "is_default": r.is_default}
        for r in rows
    ]


async def create_resume(db: AsyncSession, user_id: int, payload) -> dict:
    resume = Resume(user_id=user_id, title=payload.title, content=payload.content, version=1, is_default=1)
    db.add(resume)
    await db.commit()
    await db.refresh(resume)
    return {"id": resume.id, "title": resume.title, "content": resume.content, "version": resume.version}


async def get_default_resume(db: AsyncSession, user_id: int) -> Resume | None:
    rows = (
        await db.execute(
            select(Resume).where(Resume.user_id == user_id, Resume.is_default == 1).order_by(Resume.id.desc())
        )
    ).scalars().first()
    return rows
