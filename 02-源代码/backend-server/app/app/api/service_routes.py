"""DEPRECATED: Split into app.api.v1.discussion and .sign. This file is kept for backward compatibility only."""
from __future__ import annotations

import hashlib
import hmac
from datetime import datetime, timedelta

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth import current_user, require_roles
from app.core.config import settings
from app.core.response import success
from app.database import get_db
from app.models import DiscussionPost, DiscussionReply, SensitiveWord, SignRecord, SignTask, User
from app.schemas import DiscussionCreate, ReplyCreate, ReportCreate, SignScan, SignTaskCreate
from app.services.sensitive import scan_sensitive

router = APIRouter()


async def _sensitive_words(db: AsyncSession) -> list[str]:
    rows = (await db.execute(select(SensitiveWord.word))).scalars().all()
    return list(rows)


# ---------------------------------------------------------------------------
# 讨论区
# ---------------------------------------------------------------------------
@router.get("/discussions", tags=["discussion"])
async def list_discussions(course_id: int | None = None, db: AsyncSession = Depends(get_db)):
    statement = select(DiscussionPost).where(DiscussionPost.review_status == 1, DiscussionPost.status == 1)
    if course_id is not None:
        statement = statement.where(DiscussionPost.course_id == course_id)
    posts = (await db.execute(statement.order_by(DiscussionPost.is_pinned.desc(), DiscussionPost.created_at.desc()))).scalars().all()
    return success([
        {
            "id": p.id,
            "course_id": p.course_id,
            "user_id": p.user_id,
            "title": p.title,
            "content": p.content,
            "is_pinned": p.is_pinned,
            "like_count": p.like_count,
            "created_at": p.created_at,
        }
        for p in posts
    ])


@router.post("/discussions", tags=["discussion"])
async def create_discussion(payload: DiscussionCreate, db: AsyncSession = Depends(get_db), user=Depends(current_user)):
    words = await _sensitive_words(db)
    hits = scan_sensitive(f"{payload.title or ''}\n{payload.content}", words)
    post = DiscussionPost(
        course_id=payload.course_id,
        user_id=user.id,
        title=payload.title,
        content=payload.content,
        review_status=0 if hits else 1,  # 命中敏感词则先审
    )
    db.add(post)
    await db.commit()
    await db.refresh(post)
    return success({
        "id": post.id,
        "course_id": post.course_id,
        "title": post.title,
        "content": post.content,
        "review_status": post.review_status,
        "sensitive_hits": hits,
    })


@router.post("/discussions/{post_id}/replies", tags=["discussion"])
async def create_reply(post_id: int, payload: ReplyCreate, db: AsyncSession = Depends(get_db), user=Depends(current_user)):
    post = await db.get(DiscussionPost, post_id)
    if not post or post.status != 1:
        raise HTTPException(404, "帖子不存在")
    words = await _sensitive_words(db)
    hits = scan_sensitive(payload.content, words)
    reply = DiscussionReply(
        post_id=post_id,
        user_id=user.id,
        content=payload.content,
        reply_to_id=payload.reply_to_id,
        review_status=0 if hits else 1,
    )
    db.add(reply)
    await db.commit()
    await db.refresh(reply)
    return success({"id": reply.id, "post_id": reply.post_id, "content": reply.content, "review_status": reply.review_status})


@router.post("/discussions/{post_id}/like", tags=["discussion"])
async def like_discussion(post_id: int, db: AsyncSession = Depends(get_db), user=Depends(current_user)):
    post = await db.get(DiscussionPost, post_id)
    if not post or post.status != 1:
        raise HTTPException(404, "帖子不存在")
    post.like_count = (post.like_count or 0) + 1
    await db.commit()
    return success({"id": post.id, "like_count": post.like_count})


@router.delete("/discussions/{post_id}", tags=["discussion"])
async def delete_discussion(post_id: int, db: AsyncSession = Depends(get_db), user=Depends(require_roles("TEACHER", "ADMIN"))):
    post = await db.get(DiscussionPost, post_id)
    if not post:
        raise HTTPException(404, "帖子不存在")
    post.status = 0  # 软删除（下架）
    await db.commit()
    return success({"id": post_id, "deleted": True})


@router.post("/reports", tags=["discussion"])
async def report_content(payload: ReportCreate, db: AsyncSession = Depends(get_db), user=Depends(current_user)):
    target_type = payload.target_type.upper()
    if target_type == "POST":
        obj = await db.get(DiscussionPost, payload.target_id)
    elif target_type == "REPLY":
        obj = await db.get(DiscussionReply, payload.target_id)
    else:
        raise HTTPException(422, "target_type 必须是 POST 或 REPLY")
    if not obj:
        raise HTTPException(404, "举报对象不存在")
    obj.review_status = 0  # 重新进入审核队列
    await db.commit()
    return success({"target_type": target_type, "target_id": payload.target_id, "review_status": 0})


# ---------------------------------------------------------------------------
# 扫码签到
# ---------------------------------------------------------------------------
def _sign_token(task_id: int, expire_ts: int) -> str:
    payload = f"{task_id}:{expire_ts}".encode()
    return hmac.new(settings.jwt_secret_key.encode(), payload, hashlib.sha256).hexdigest()


@router.post("/sign/tasks", tags=["sign"])
async def create_sign_task(payload: SignTaskCreate, db: AsyncSession = Depends(get_db), user=Depends(require_roles("TEACHER", "ADMIN"))):
    expire_at = datetime.utcnow() + timedelta(minutes=max(1, payload.expire_min))
    task = SignTask(
        course_id=payload.course_id,
        qrcode_token="",
        geo_enabled=payload.geo_enabled,
        geo_lat=payload.geo_lat,
        geo_lng=payload.geo_lng,
        expire_at=expire_at,
        created_by=user.id,
    )
    db.add(task)
    await db.flush()
    task.qrcode_token = _sign_token(task.id, int(expire_at.timestamp()))
    await db.commit()
    await db.refresh(task)
    return success({"id": task.id, "course_id": task.course_id, "qrcode_token": task.qrcode_token, "expire_at": task.expire_at})


@router.post("/sign/scan", tags=["sign"])
async def scan_sign(payload: SignScan, db: AsyncSession = Depends(get_db), user=Depends(current_user)):
    task = await db.get(SignTask, payload.task_id)
    if not task:
        raise HTTPException(404, "签到任务不存在")
    now = datetime.utcnow()
    if now > task.expire_at:
        raise HTTPException(410, "签到已过期")
    expect = _sign_token(task.id, int(task.expire_at.timestamp()))
    if not hmac.compare_digest(expect, payload.token):
        raise HTTPException(403, "二维码无效")

    existing = await db.scalar(select(SignRecord).where(SignRecord.task_id == task.id, SignRecord.user_id == user.id))
    if existing:
        return success({"id": existing.id, "task_id": task.id, "is_valid": existing.is_valid, "already": True})
    record = SignRecord(task_id=task.id, user_id=user.id, is_valid=1)
    db.add(record)
    await db.commit()
    await db.refresh(record)
    return success({"id": record.id, "task_id": task.id, "is_valid": record.is_valid, "already": False})


@router.get("/sign/tasks/{task_id}/records", tags=["sign"])
async def sign_records(task_id: int, db: AsyncSession = Depends(get_db), user=Depends(require_roles("TEACHER", "ADMIN"))):
    rows = (
        await db.execute(
            select(SignRecord, User)
            .join(User, User.id == SignRecord.user_id)
            .where(SignRecord.task_id == task_id)
            .order_by(SignRecord.sign_at)
        )
    ).all()
    return success([
        {"id": record.id, "user_id": record.user_id, "username": usr.username,
         "real_name": usr.real_name, "sign_at": record.sign_at, "is_valid": record.is_valid}
        for record, usr in rows
    ])
