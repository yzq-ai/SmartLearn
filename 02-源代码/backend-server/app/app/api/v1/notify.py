from __future__ import annotations

from fastapi import APIRouter, Depends
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth import current_user, require_roles
from app.core.response import success
from app.database import get_db
from app.models import Notification, NotificationRead, User

router = APIRouter()


async def _role_notification_ids(db: AsyncSession, user: User) -> list[int]:
    rows = (
        await db.execute(
            select(Notification.id).where(
                (Notification.target_role == "ALL") | (Notification.target_role == user.role)
            )
        )
    ).scalars().all()
    return list(rows)


@router.get("/notifications", tags=["notify"])
async def list_notifications(db: AsyncSession = Depends(get_db), user=Depends(current_user)):
    rows = (
        await db.execute(
            select(Notification).where(
                (Notification.target_role == "ALL") | (Notification.target_role == user.role)
            ).order_by(Notification.created_at.desc())
        )
    ).scalars().all()
    read_ids = set(
        (
            await db.execute(
                select(NotificationRead.notification_id).where(NotificationRead.user_id == user.id)
            )
        ).scalars().all()
    )
    return success([
        {
            "id": n.id, "type": n.type, "title": n.title, "content": n.content,
            "created_at": n.created_at, "is_read": 1 if n.id in read_ids else 0,
        }
        for n in rows
    ])


@router.post("/notifications", tags=["notify"])
async def create_notification(payload: dict, db: AsyncSession = Depends(get_db), user=Depends(require_roles("TEACHER", "ADMIN"))):
    from app.services.push_service import send_push

    n = Notification(
        type=payload.get("type", "SYSTEM"),
        title=payload.get("title", ""),
        content=payload.get("content", ""),
        sender_id=user.id,
        target_role=payload.get("target_role", "ALL"),
        target_course_id=payload.get("target_course_id"),
    )
    pushed = send_push([], n.title, n.content or "")
    n.push_sent = 1 if pushed else 0
    db.add(n)
    await db.commit()
    await db.refresh(n)
    return success({"id": n.id, "type": n.type, "title": n.title, "target_role": n.target_role, "push_sent": n.push_sent})


@router.put("/notifications/{notification_id}/read", tags=["notify"])
async def mark_notification_read(notification_id: int, db: AsyncSession = Depends(get_db), user=Depends(current_user)):
    exists = (
        await db.execute(
            select(NotificationRead).where(
                NotificationRead.user_id == user.id, NotificationRead.notification_id == notification_id
            )
        )
    ).scalar_one_or_none()
    if not exists:
        db.add(NotificationRead(user_id=user.id, notification_id=notification_id))
        await db.commit()
    return success({"notification_id": notification_id, "read": True})


@router.put("/notifications/read-all", tags=["notify"])
async def mark_all_notifications_read(db: AsyncSession = Depends(get_db), user=Depends(current_user)):
    ids = await _role_notification_ids(db, user)
    existing = set(
        (await db.execute(select(NotificationRead.notification_id).where(NotificationRead.user_id == user.id))).scalars().all()
    )
    for nid in ids:
        if nid not in existing:
            db.add(NotificationRead(user_id=user.id, notification_id=nid))
    await db.commit()
    return success({"read": len(ids)})


@router.get("/notifications/unread-count", tags=["notify"])
async def unread_notification_count(db: AsyncSession = Depends(get_db), user=Depends(current_user)):
    ids = await _role_notification_ids(db, user)
    read = set(
        (await db.execute(select(NotificationRead.notification_id).where(NotificationRead.user_id == user.id))).scalars().all()
    )
    return success({"unread": sum(1 for nid in ids if nid not in read)})
