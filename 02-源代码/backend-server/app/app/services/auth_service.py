"""Authentication logic: login, logout, register, token refresh, password management.

All DB-mutating functions accept an AsyncSession for dependency injection.
"""
from __future__ import annotations

from datetime import datetime, timedelta

from fastapi import HTTPException
from jose import JWTError
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth import (
    create_access_token, create_refresh_token, decode_token, hash_password, verify_password,
)
from app.core.audit import write_audit
from app.models import SysLoginLog, User
from app.services.security_service import (
    blacklist_token, clear_login_failures, is_login_locked, record_login_failure,
)


async def login_flow(db: AsyncSession, username: str, password: str) -> dict:
    if await is_login_locked(username):
        raise HTTPException(423, "账号已锁定 15 分钟")
    user = (await db.execute(select(User).where(User.username == username))).scalar_one_or_none()
    if not user or not verify_password(password, user.password_hash):
        await record_login_failure(username)
        if user:
            db.add(SysLoginLog(user_id=user.id, result=0, fail_reason="账号或密码错误"))
            await db.commit()
        raise HTTPException(401, "账号或密码错误")
    if user.status != 1:
        raise HTTPException(403, "账号已禁用")
    await clear_login_failures(username)
    db.add(SysLoginLog(user_id=user.id, result=1))
    await db.commit()
    return _build_token_payload(user)


async def register_flow(db: AsyncSession, username: str, password: str) -> dict:
    if (await db.execute(select(User).where(User.username == username))).scalar_one_or_none():
        raise HTTPException(409, "用户名已存在")
    user = User(username=username, password_hash=hash_password(password), role="STUDENT", pwd_changed=0)
    db.add(user)
    await db.commit()
    await db.refresh(user)
    return _build_token_payload(user)


async def refresh_flow(db: AsyncSession, refresh_token: str) -> dict:
    try:
        data = decode_token(refresh_token, expected_type="refresh")
        user_id = int(data.get("sub", 0))
    except (JWTError, ValueError, TypeError):
        raise HTTPException(401, "无效或过期令牌")
    user = await db.get(User, user_id)
    if not user or user.status != 1:
        raise HTTPException(401, "无效或过期令牌")
    return _build_token_payload(user)


async def logout_flow(access_token: str, refresh_token_body: dict | None = None) -> dict:
    try:
        data = decode_token(access_token, expected_type="access")
        jti = data.get("jti", "")
        exp = int(data.get("exp", 0))
    except JWTError:
        raise HTTPException(401, "无效或过期令牌")
    remaining = max(1, exp - int(datetime.utcnow().timestamp()))
    if jti:
        await blacklist_token(jti, remaining)
    if refresh_token_body:
        try:
            rdata = decode_token(refresh_token_body, expected_type="refresh")
            rjti = rdata.get("jti", "")
            rexp = int(rdata.get("exp", 0))
            await blacklist_token(rjti, max(1, rexp - int(datetime.utcnow().timestamp())))
        except JWTError:
            pass
    return {"logout": True}


async def change_password_flow(db: AsyncSession, user, old_password: str, new_password: str) -> dict:
    if not verify_password(old_password, user.password_hash):
        raise HTTPException(400, "原密码错误")
    user.password_hash = hash_password(new_password)
    user.pwd_changed = 1
    await write_audit(db, user.id, "PASSWORD_CHANGE", "USER", user.id)
    await db.commit()
    return {"changed": True}


async def deactivate_flow(db: AsyncSession, user) -> dict:
    user.deleted_at = datetime.utcnow() + timedelta(days=7)
    await write_audit(db, user.id, "DEACTIVATE", "USER", user.id)
    await db.commit()
    return {"deactivate": True, "deleted_at": user.deleted_at}


async def cancel_deactivate_flow(db: AsyncSession, user) -> dict:
    user.deleted_at = None
    await db.commit()
    return {"deactivate": False}


def _build_token_payload(user) -> dict:
    return {
        "access_token": create_access_token(user),
        "refresh_token": create_refresh_token(str(user.id)),
        "token_type": "bearer",
        "pwd_changed": user.pwd_changed,
        "user": {"id": user.id, "username": user.username, "role": user.role},
    }
