"""Notification logic: creation, read status management, unread count.

All DB-mutating functions accept an AsyncSession for dependency injection.
"""
from __future__ import annotations

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import Notification, NotificationRead, User


async def role_notification_ids(db: AsyncSession, user: User) -> list[int]:
    rows = (
        await db.execute(
            select(Notification.id).where(
                (Notification.target_role == "ALL") | (Notification.target_role == user.role)
            )
        )
    ).scalars().all()
    return list(rows)


async def list_notifications(db: AsyncSession, user: User) -> list[dict]:
    rows = (
        await db.execute(
            select(Notification).where(
                (Notification.target_role == "ALL") | (Notification.target_role == user.role)
            ).order_by(Notification.created_at.desc())
        )
    ).scalars().all()
    return [
        {"id": n.id, "type": n.type, "title": n.title, "content": n.content, "created_at": n.created_at}
        for n in rows
    ]


async def create_notification(db: AsyncSession, payload: dict, sender_id: int) -> dict:
    from app.services.push_service import send_push

    n = Notification(
        type=payload.get("type", "SYSTEM"),
        title=payload.get("title", ""),
        content=payload.get("content", ""),
        sender_id=sender_id,
        target_role=payload.get("target_role", "ALL"),
        target_course_id=payload.get("target_course_id"),
    )
    pushed = send_push([], n.title, n.content or "")
    n.push_sent = 1 if pushed else 0
    db.add(n)
    await db.commit()
    await db.refresh(n)
    return {"id": n.id, "type": n.type, "title": n.title, "target_role": n.target_role, "push_sent": n.push_sent}


async def mark_notification_read(db: AsyncSession, user_id: int, notification_id: int) -> dict:
    exists = (
        await db.execute(
            select(NotificationRead).where(
                NotificationRead.user_id == user_id, NotificationRead.notification_id == notification_id
            )
        )
    ).scalar_one_or_none()
    if not exists:
        db.add(NotificationRead(user_id=user_id, notification_id=notification_id))
        await db.commit()
    return {"notification_id": notification_id, "read": True}


async def mark_all_notifications_read(db: AsyncSession, user: User) -> dict:
    ids = await role_notification_ids(db, user)
    existing = set(
        (await db.execute(
            select(NotificationRead.notification_id).where(NotificationRead.user_id == user.id)
        )).scalars().all()
    )
    for nid in ids:
        if nid not in existing:
            db.add(NotificationRead(user_id=user.id, notification_id=nid))
    await db.commit()
    return {"read": len(ids)}


async def unread_notification_count(db: AsyncSession, user: User) -> dict:
    ids = await role_notification_ids(db, user)
    read = set(
        (await db.execute(
            select(NotificationRead.notification_id).where(NotificationRead.user_id == user.id)
        )).scalars().all()
    )
    return {"unread": sum(1 for nid in ids if nid not in read)}
