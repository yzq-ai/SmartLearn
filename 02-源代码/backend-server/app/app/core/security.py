"""Password hashing and JWT helpers.

Passwords are hashed with BCrypt (passlib). Tokens are HS256-signed and carry
``sub``/``role``/``type``/``jti``/``exp`` claims. ``type`` is ``access`` or
``refresh`` so each can only be used for its intended endpoint.
"""
from __future__ import annotations

import uuid
from datetime import datetime, timedelta, timezone

from jose import JWTError, jwt
from passlib.context import CryptContext

from app.core.config import settings

pwd_context = CryptContext(schemes=["bcrypt_sha256", "bcrypt"], deprecated="auto")


def hash_password(password: str) -> str:
    return pwd_context.hash(password)


def verify_password(password: str, hashed: str) -> bool:
    try:
        return pwd_context.verify(password, hashed)
    except Exception:
        return False


def _now() -> datetime:
    return datetime.now(timezone.utc)


def create_access_token(subject: str, role: str) -> str:
    expire = _now() + timedelta(minutes=settings.access_token_expire_minutes)
    return jwt.encode(
        {"sub": subject, "role": role, "type": "access", "jti": uuid.uuid4().hex, "exp": expire},
        settings.jwt_secret_key,
        algorithm=settings.jwt_algorithm,
    )


def create_refresh_token(subject: str) -> str:
    expire = _now() + timedelta(days=settings.refresh_token_expire_days)
    return jwt.encode(
        {"sub": subject, "type": "refresh", "jti": uuid.uuid4().hex, "exp": expire},
        settings.jwt_secret_key,
        algorithm=settings.jwt_algorithm,
    )


def decode_token(token: str, expected_type: str | None = None) -> dict:
    payload = jwt.decode(token, settings.jwt_secret_key, algorithms=[settings.jwt_algorithm])
    if expected_type is not None and payload.get("type") != expected_type:
        raise JWTError(f"token type is not {expected_type}")
    return payload


__all__ = [
    "hash_password",
    "verify_password",
    "create_access_token",
    "create_refresh_token",
    "decode_token",
]
