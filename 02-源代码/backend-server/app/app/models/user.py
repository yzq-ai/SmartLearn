from __future__ import annotations

from datetime import datetime

from sqlalchemy import JSON, Integer, String, Text, DateTime, ForeignKey
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


class User(Base):
    __tablename__ = "sys_user"

    id: Mapped[int] = mapped_column(primary_key=True)
    username: Mapped[str] = mapped_column(String(64), unique=True)
    user_code: Mapped[str | None] = mapped_column(String(12), unique=True, nullable=True, default=None)  # 唯一用户号（用于搜索添加好友/老师）
    password_hash: Mapped[str] = mapped_column(String(255))
    real_name: Mapped[str] = mapped_column(String(64), default="")
    role: Mapped[str] = mapped_column("role_code", String(20), default="STUDENT")
    gender: Mapped[int] = mapped_column(Integer, default=0)
    phone_enc: Mapped[str | None] = mapped_column(String(128), nullable=True)
    email: Mapped[str | None] = mapped_column(String(100), nullable=True)
    major: Mapped[str | None] = mapped_column(String(50), nullable=True)
    class_name: Mapped[str | None] = mapped_column(String(50), nullable=True)
    grade: Mapped[str | None] = mapped_column(String(20), nullable=True)
    department: Mapped[str | None] = mapped_column(String(50), nullable=True)
    title: Mapped[str | None] = mapped_column(String(50), nullable=True)
    avatar_url: Mapped[str | None] = mapped_column(String(255), nullable=True)
    signature: Mapped[str | None] = mapped_column(String(200), default="", nullable=True)
    status: Mapped[int] = mapped_column(Integer, default=1)
    pwd_changed: Mapped[int] = mapped_column(Integer, default=0)
    deleted_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)


class SysLoginLog(Base):
    __tablename__ = "sys_login_log"

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("sys_user.id"), index=True)
    login_type: Mapped[int] = mapped_column(Integer, default=1)
    ip: Mapped[str | None] = mapped_column(String(50), nullable=True)
    device: Mapped[str | None] = mapped_column(String(100), nullable=True)
    result: Mapped[int | None] = mapped_column(Integer, nullable=True)
    fail_reason: Mapped[str | None] = mapped_column(String(100), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)


class SysAuditLog(Base):
    __tablename__ = "sys_audit_log"

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int | None] = mapped_column(ForeignKey("sys_user.id"), nullable=True)
    action: Mapped[str] = mapped_column(String(50))
    target_type: Mapped[str | None] = mapped_column(String(30), nullable=True)
    target_id: Mapped[int | None] = mapped_column(Integer, nullable=True)
    detail: Mapped[dict | None] = mapped_column(JSON, nullable=True)
    ip: Mapped[str | None] = mapped_column(String(50), nullable=True)
    device: Mapped[str | None] = mapped_column(String(100), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)


class SysConfig(Base):
    __tablename__ = "sys_config"

    cfg_key: Mapped[str] = mapped_column(String(50), primary_key=True)
    cfg_value: Mapped[str] = mapped_column(Text)
    remark: Mapped[str | None] = mapped_column(String(200), nullable=True)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)


class SensitiveWord(Base):
    __tablename__ = "sensitive_word"

    id: Mapped[int] = mapped_column(primary_key=True)
    word: Mapped[str] = mapped_column(String(100), unique=True)
    level: Mapped[int] = mapped_column(Integer, default=1)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)


__all__ = ["User", "SysLoginLog", "SysAuditLog", "SysConfig", "SensitiveWord"]
