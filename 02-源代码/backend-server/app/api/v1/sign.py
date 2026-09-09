"""课堂签到 v2：4 位数字码 + 30 秒时限 + 教师查看未签名单/手动补签/作废。

流程：
- 教师「发起签到」→ 生成随机 4 位数字码（qrcode_token），有效期 30 秒（expire_at）。
- 学生输入 4 位数字码签到（sign/scan 改为 sign/checkin，校验码+时限，幂等）。
- 教师拉取「全部选课学生 + 签到状态」列表（sign/attendance）。
- 教师可手动置某学生为已签/未签（sign/manual，补签或作废）。
"""
from __future__ import annotations

import random
from datetime import datetime, timedelta

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth import current_user, require_roles
from app.core.response import success
from app.database import get_db
from app.models import CourseEnrollment, SignRecord, SignTask, User
from app.schemas import SignCheckin, SignTaskCreate

router = APIRouter()

SIGN_WINDOW_SECONDS = 30  # 签到码有效期 30 秒


def _gen_code() -> str:
    """随机 4 位数字码（保证 4 位，不以 0 开头以外无约束）。"""
    return f"{random.randint(1000, 9999)}"


@router.post("/sign/tasks", tags=["sign"])
async def create_sign_task(payload: SignTaskCreate, db: AsyncSession = Depends(get_db), user=Depends(require_roles("TEACHER", "ADMIN"))):
    expire_at = datetime.utcnow() + timedelta(seconds=SIGN_WINDOW_SECONDS)
    task = SignTask(
        course_id=payload.course_id,
        qrcode_token=_gen_code(),
        geo_enabled=payload.geo_enabled,
        geo_lat=payload.geo_lat,
        geo_lng=payload.geo_lng,
        expire_at=expire_at,
        created_by=user.id,
    )
    db.add(task)
    await db.flush()
    await db.commit()
    await db.refresh(task)
    remaining = max(0, int((task.expire_at - datetime.utcnow()).total_seconds()))
    return success({
        "id": task.id,
        "course_id": task.course_id,
        "code": task.qrcode_token,
        "expire_at": task.expire_at,
        "remaining_seconds": remaining,
        "window_seconds": SIGN_WINDOW_SECONDS,
    })


@router.get("/sign/tasks/latest", tags=["sign"])
async def latest_sign_task(course_id: int, db: AsyncSession = Depends(get_db), user=Depends(current_user)):
    """学生端拉最新签到任务（4 位码输入页展示剩余秒数）。"""
    task = (
        await db.execute(
            select(SignTask)
            .where(SignTask.course_id == course_id)
            .order_by(SignTask.id.desc())
            .limit(1)
        )
    ).scalar_one_or_none()
    if not task:
        raise HTTPException(404, "暂无签到任务")
    remaining = max(0, int((task.expire_at - datetime.utcnow()).total_seconds()))
    return success({
        "id": task.id,
        "course_id": task.course_id,
        "expire_at": task.expire_at,
        "remaining_seconds": remaining,
        "expired": remaining <= 0,
    })


@router.post("/sign/checkin", tags=["sign"])
async def checkin_sign(payload: SignCheckin, db: AsyncSession = Depends(get_db), user=Depends(current_user)):
    """学生输入 4 位数字码签到。"""
    task = await db.get(SignTask, payload.task_id)
    if not task:
        raise HTTPException(404, "签到任务不存在")
    now = datetime.utcnow()
    if now > task.expire_at:
        raise HTTPException(410, "签到码已过期（限时 30 秒），请联系教师重新发起")
    if (payload.code or "").strip() != task.qrcode_token:
        raise HTTPException(403, "签到码不正确")

    existing = await db.scalar(select(SignRecord).where(SignRecord.task_id == task.id, SignRecord.user_id == user.id))
    if existing:
        return success({"id": existing.id, "task_id": task.id, "is_valid": existing.is_valid, "already": True})
    record = SignRecord(task_id=task.id, user_id=user.id, is_valid=1)
    db.add(record)
    await db.commit()
    await db.refresh(record)
    return success({"id": record.id, "task_id": task.id, "is_valid": record.is_valid, "already": False})


@router.get("/sign/tasks/{task_id}/attendance", tags=["sign"])
async def sign_attendance(task_id: int, db: AsyncSession = Depends(get_db), user=Depends(require_roles("TEACHER", "ADMIN"))):
    """教师端签到名单：全部选课学生 + 是否已签（未签的也列出）。"""
    task = await db.get(SignTask, task_id)
    if not task:
        raise HTTPException(404, "签到任务不存在")
    students = (
        await db.execute(
            select(User)
            .join(CourseEnrollment, CourseEnrollment.user_id == User.id)
            .where(CourseEnrollment.course_id == task.course_id, User.role == "STUDENT")
            .order_by(User.username)
        )
    ).scalars().all()
    records = {
        r.user_id: r
        for r in (
            await db.execute(select(SignRecord).where(SignRecord.task_id == task_id))
        ).scalars()
    }
    out = []
    signed = 0
    for s in students:
        rec = records.get(s.id)
        valid = bool(rec and rec.is_valid == 1)
        if valid:
            signed += 1
        out.append({
            "user_id": s.id, "username": s.username, "real_name": s.real_name,
            "signed": valid, "sign_at": rec.sign_at if rec else None,
            "is_manual": False if rec is None else bool(getattr(rec, "is_manual", False)) if hasattr(rec, "is_manual") else False,
        })
    remaining = max(0, int((task.expire_at - datetime.utcnow()).total_seconds()))
    return success({
        "task_id": task_id,
        "course_id": task.course_id,
        "code": task.qrcode_token,
        "remaining_seconds": remaining,
        "expired": remaining <= 0,
        "total": len(students),
        "signed": signed,
        "unsigned": len(students) - signed,
        "students": out,
    })


@router.post("/sign/tasks/{task_id}/manual", tags=["sign"])
async def manual_sign(task_id: int, payload: dict, db: AsyncSession = Depends(get_db), user=Depends(require_roles("TEACHER", "ADMIN"))):
    """教师手动补签/作废：{user_id, signed: true/false}。"""
    target_user_id = payload.get("user_id")
    signed = bool(payload.get("signed"))
    if not target_user_id:
        raise HTTPException(422, "缺少 user_id")
    task = await db.get(SignTask, task_id)
    if not task:
        raise HTTPException(404, "签到任务不存在")
    record = await db.scalar(
        select(SignRecord).where(SignRecord.task_id == task_id, SignRecord.user_id == target_user_id)
    )
    if signed:
        if record:
            record.is_valid = 1
        else:
            db.add(SignRecord(task_id=task_id, user_id=target_user_id, is_valid=1))
        action = "补签成功"
    else:
        if record:
            record.is_valid = 0
        action = "已作废该签到"
    await db.commit()
    return success({"task_id": task_id, "user_id": target_user_id, "signed": signed, "message": action})


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
