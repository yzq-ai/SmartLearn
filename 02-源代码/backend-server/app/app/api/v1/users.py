from __future__ import annotations

from datetime import datetime, timedelta

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth import current_user
from app.core.audit import write_audit
from app.core.response import success
from app.database import get_db
from app.models import User
from app.services.obs import create_upload_token

router = APIRouter()


class UserProfileUpdate(BaseModel):
    """个人资料编辑。username/real_name/email/phone/signature 均可选。"""

    username: str | None = Field(default=None, min_length=1, max_length=64)
    real_name: str | None = Field(default=None, max_length=64)
    signature: str | None = Field(default=None, max_length=200)
    email: str | None = Field(default=None, max_length=100)
    phone: str | None = Field(default=None, max_length=20)


class AvatarUpdate(BaseModel):
    oss_key: str = Field(min_length=1, max_length=255)


def _profile_out(user: User) -> dict:
    return {
        "id": user.id,
        "username": user.username,
        "user_code": user.user_code or f"SL{user.id:06d}",
        "real_name": user.real_name or "",
        "role": user.role,
        "avatar": user.avatar_url or "",
        "signature": user.signature or "",
        "email": user.email or "",
        "phone": user.phone_enc or "",
        "major": user.major or "",
        "class_name": user.class_name or "",
        "grade": user.grade or "",
        "department": user.department or "",
        "title": user.title or "",
    }


@router.get("/users/me/profile", tags=["users"])
@router.get("/user/profile", tags=["users"], include_in_schema=False)  # 兼容旧客户端路径
async def get_my_profile(db: AsyncSession = Depends(get_db), user=Depends(current_user)):
    return success(_profile_out(user))


@router.put("/users/me/profile", tags=["users"])
@router.put("/user/profile", tags=["users"], include_in_schema=False)  # 兼容旧客户端路径
async def update_my_profile(
    payload: UserProfileUpdate, db: AsyncSession = Depends(get_db), user=Depends(current_user)
):
    if payload.username is not None and payload.username != user.username:
        exists = (
            await db.execute(select(User).where(User.username == payload.username, User.id != user.id))
        ).scalar_one_or_none()
        if exists:
            raise HTTPException(409, "用户名已被占用")
        user.username = payload.username
    if payload.real_name is not None:
        user.real_name = payload.real_name
    if payload.signature is not None:
        user.signature = payload.signature
    if payload.email is not None:
        user.email = payload.email
    if payload.phone is not None:
        user.phone_enc = payload.phone
    await write_audit(db, user.id, "UPDATE", "USER", user.id)
    await db.commit()
    await db.refresh(user)
    return success(_profile_out(user))


@router.post("/users/me/avatar", tags=["users"])
@router.post("/user/avatar", tags=["users"], include_in_schema=False)  # 兼容旧客户端路径
async def update_my_avatar(
    payload: AvatarUpdate, db: AsyncSession = Depends(get_db), user=Depends(current_user)
):
    # OSS 模式下 oss_key 指向上传对象；local 模式退化为直接存值。
    user.avatar_url = payload.oss_key
    await write_audit(db, user.id, "UPDATE", "USER", user.id, detail={"field": "avatar"})
    await db.commit()
    await db.refresh(user)
    return success(_profile_out(user))


@router.post("/users/me/deactivate", tags=["auth"])
async def deactivate(db: AsyncSession = Depends(get_db), user=Depends(current_user)):
    user.deleted_at = datetime.utcnow() + timedelta(days=7)
    await write_audit(db, user.id, "DEACTIVATE", "USER", user.id)
    await db.commit()
    return success({"deactivate": True, "deleted_at": user.deleted_at})


@router.post("/users/me/deactivate/cancel", tags=["auth"])
async def cancel_deactivate(db: AsyncSession = Depends(get_db), user=Depends(current_user)):
    user.deleted_at = None
    await db.commit()
    return success({"deactivate": False})
