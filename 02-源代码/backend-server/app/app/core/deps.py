"""Authentication dependencies: current-user resolution and RBAC gates.

``get_current_user`` 校验 access token 类型、Token 黑名单与用户状态；
``require_roles`` / ``require_perm`` 是服务端二次鉴权闸门。
"""
from typing import Annotated

from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from jose import JWTError
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import decode_token
from app.database import get_db
from app.models import User
from app.services.security_service import is_token_blacklisted

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/v1/auth/login")
oauth2_scheme_optional = OAuth2PasswordBearer(tokenUrl="/api/v1/auth/login", auto_error=False)

_credentials_error = HTTPException(
    status_code=status.HTTP_401_UNAUTHORIZED,
    detail="无效或过期令牌",
    headers={"WWW-Authenticate": "Bearer"},
)


async def get_current_user(
    token: Annotated[str, Depends(oauth2_scheme)],
    db: Annotated[AsyncSession, Depends(get_db)],
) -> User:
    try:
        payload = decode_token(token, expected_type="access")
        user_id = int(payload.get("sub", 0))
        jti = payload.get("jti", "")
    except (JWTError, ValueError, TypeError):
        raise _credentials_error
    if jti and await is_token_blacklisted(jti):
        raise _credentials_error
    user = await db.scalar(select(User).where(User.id == user_id, User.status == 1))
    if not user:
        raise _credentials_error
    return user


def require_roles(*roles: str):
    async def checker(user: Annotated[User, Depends(get_current_user)]) -> User:
        if user.role not in roles:
            raise HTTPException(status_code=403, detail="权限不足")
        return user

    return checker


async def get_optional_user(
    token: Annotated[str | None, Depends(oauth2_scheme_optional)],
    db: Annotated[AsyncSession, Depends(get_db)],
) -> User | None:
    """未登录返回 None；登录则校验，token 无效时也返回 None（用于可选个性化）。"""
    if not token:
        return None
    try:
        payload = decode_token(token, expected_type="access")
        user_id = int(payload.get("sub", 0))
        jti = payload.get("jti", "")
    except (JWTError, ValueError, TypeError):
        return None
    if jti and await is_token_blacklisted(jti):
        return None
    return await db.scalar(select(User).where(User.id == user_id, User.status == 1))


# 完整 RBAC 权限码（对齐文档 4.2）。
_ROLE_PERMS: dict[str, set[str]] = {
    "ADMIN": {"*"},
    "TEACHER": {
        "course:create", "course:update", "course:publish", "course:delete",
        "assignment:create", "assignment:grade",
        "question:ai-draft", "question:approve",
        "exam:create", "exam:monitor", "exam:grade:subjective",
        "score:view:class", "score:view:all",
        "job:create", "job:review", "ai:use",
        "audit:view",
    },
    "STUDENT": {
        "assignment:submit", "exam:take", "score:view:self", "ai:use",
    },
}


def require_perm(perm: str):
    async def checker(user: Annotated[User, Depends(get_current_user)]) -> User:
        perms = _ROLE_PERMS.get(user.role, set())
        if "*" not in perms and perm not in perms:
            raise HTTPException(status_code=403, detail="您没有该操作权限")
        return user

    return checker
