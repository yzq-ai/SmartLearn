"""审计日志写入（操作只增不删）。

在关键写操作后调用 ``write_audit``，记录 who/action/target/detail，落 ``sys_audit_log``。
"""
from __future__ import annotations

from typing import Any

from sqlalchemy.ext.asyncio import AsyncSession

from app.models import SysAuditLog


async def write_audit(
    db: AsyncSession,
    user_id: int | None,
    action: str,
    target_type: str | None = None,
    target_id: int | None = None,
    detail: dict[str, Any] | None = None,
) -> None:
    db.add(SysAuditLog(
        user_id=user_id,
        action=action,
        target_type=target_type,
        target_id=target_id,
        detail=detail,
    ))
