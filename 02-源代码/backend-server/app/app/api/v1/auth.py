from __future__ import annotations

from datetime import datetime

from fastapi import APIRouter, Body, Depends, HTTPException
from jose import JWTError
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth import (
    create_access_token, create_refresh_token, current_user, decode_token,
    hash_password, oauth2_scheme, verify_password,
)
from app.core.audit import write_audit
from app.core.response import success
from app.database import get_db
from app.models import SysLoginLog, User
from app.schemas import LoginRequest, PasswordChange, RefreshRequest, RegisterRequest
from app.services.security_service import (
    blacklist_token, clear_login_failures, is_login_locked, record_login_failure,
)

router = APIRouter()


@router.post("/auth/login", tags=["auth"])
async def login(payload: LoginRequest, db: AsyncSession = Depends(get_db)):
    if await is_login_locked(payload.username):
        raise HTTPException(423, "账号已锁定 15 分钟")
    # 需求 14：用户名或唯一用户号（SLxxxxxx）均可登录
    user = (await db.execute(select(User).where(User.username == payload.username))).scalar_one_or_none()
    if user is None and payload.username.upper().startswith("SL") and len(payload.username) == 8:
        user = (
            await db.execute(select(User).where(User.user_code == payload.username.upper()))
        ).scalar_one_or_none()
    if not user or not verify_password(payload.password, user.password_hash):
        await record_login_failure(payload.username)
        if user:
            db.add(SysLoginLog(user_id=user.id, result=0, fail_reason="账号或密码错误"))
            await db.commit()
        raise HTTPException(401, "账号或密码错误")
    if user.status != 1:
        raise HTTPException(403, "账号已禁用")
    await clear_login_failures(payload.username)
    db.add(SysLoginLog(user_id=user.id, result=1))
    await db.commit()
    return success({
        "access_token": create_access_token(user),
        "refresh_token": create_refresh_token(str(user.id)),
        "token_type": "bearer",
        "pwd_changed": user.pwd_changed,
        "user": {"id": user.id, "username": user.username, "role": user.role},
    })


@router.post("/auth/register", tags=["auth"])
async def register(payload: RegisterRequest, db: AsyncSession = Depends(get_db)):
    if (await db.execute(select(User).where(User.username == payload.username))).scalar_one_or_none():
        raise HTTPException(409, "用户名已存在")
    # 注册一律创建学生账号；教师/管理员由管理员在后台创建。
    user = User(
        username=payload.username,
        password_hash=hash_password(payload.password),
        role="STUDENT",
        real_name=payload.real_name or "",
        pwd_changed=0,
    )
    db.add(user)
    await db.flush()
    user.user_code = f"SL{user.id:06d}"  # 唯一用户号（注册即分配）
    await db.commit()
    await db.refresh(user)
    return success({
        "access_token": create_access_token(user),
        "refresh_token": create_refresh_token(str(user.id)),
        "token_type": "bearer",
        "pwd_changed": user.pwd_changed,
        "user": {"id": user.id, "username": user.username, "role": user.role},
    })


@router.post("/auth/refresh", tags=["auth"])
async def refresh(payload: RefreshRequest, db: AsyncSession = Depends(get_db)):
    try:
        data = decode_token(payload.refresh_token, expected_type="refresh")
        user_id = int(data.get("sub", 0))
    except (JWTError, ValueError, TypeError):
        raise HTTPException(401, "无效或过期令牌")
    user = await db.get(User, user_id)
    if not user or user.status != 1:
        raise HTTPException(401, "无效或过期令牌")
    return success({
        "access_token": create_access_token(user),
        "refresh_token": create_refresh_token(str(user.id)),
        "token_type": "bearer",
        "pwd_changed": user.pwd_changed,
        "user": {"id": user.id, "username": user.username, "role": user.role},
    })


@router.post("/auth/logout", tags=["auth"])
async def logout(payload: dict | None = Body(default=None), token: str = Depends(oauth2_scheme)):
    try:
        data = decode_token(token, expected_type="access")
        jti = data.get("jti", "")
        exp = int(data.get("exp", 0))
    except JWTError:
        raise HTTPException(401, "无效或过期令牌")
    remaining = max(1, exp - int(datetime.utcnow().timestamp()))
    if jti:
        await blacklist_token(jti, remaining)
    refresh_token = (payload or {}).get("refresh_token")
    if refresh_token:
        try:
            rdata = decode_token(refresh_token, expected_type="refresh")
            rjti = rdata.get("jti", "")
            rexp = int(rdata.get("exp", 0))
            await blacklist_token(rjti, max(1, rexp - int(datetime.utcnow().timestamp())))
        except JWTError:
            pass
    return success({"logout": True})


@router.put("/auth/password", tags=["auth"])
async def change_password(payload: PasswordChange, db: AsyncSession = Depends(get_db), user=Depends(current_user)):
    if not verify_password(payload.old_password, user.password_hash):
        raise HTTPException(400, "原密码错误")
    user.password_hash = hash_password(payload.new_password)
    user.pwd_changed = 1
    await write_audit(db, user.id, "PASSWORD_CHANGE", "USER", user.id)
    await db.commit()
    return success({"changed": True})
