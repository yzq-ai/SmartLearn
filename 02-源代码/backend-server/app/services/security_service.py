"""认证安全辅助：Token 黑名单、登录防爆破。

生产走 Redis（SET/INCR + EXPIRE）；本地/测试无 Redis 时黑名单持久化到
SQLite（服务重启后依然生效），登录防爆破回退进程内存，保证行为一致且可单测。
"""
from __future__ import annotations

import time

from app.db.redis import get_redis

LOGIN_MAX_FAIL = 5
LOGIN_LOCK_SECONDS = 15 * 60


# ---------------------------------------------------------------------------
# Token 黑名单（Redis → SQLite 持久化 → 进程内存 三级）
# ---------------------------------------------------------------------------
_memory_blacklist: dict[str, float] = {}


async def _sqlite_blacklist_upsert(jti: str, exp_ts: float) -> None:
    """无 Redis 时把 jti 写入 SQLite，服务重启后依然生效。"""
    from app.database import SessionLocal
    from sqlalchemy import text

    async with SessionLocal() as db:
        await db.execute(
            text(
                "CREATE TABLE IF NOT EXISTS revoked_token "
                "(jti TEXT PRIMARY KEY, exp_ts REAL NOT NULL)"
            )
        )
        await db.execute(
            text("INSERT OR REPLACE INTO revoked_token (jti, exp_ts) VALUES (:j, :e)"),
            {"j": jti, "e": exp_ts},
        )
        await db.commit()


async def _sqlite_blacklist_check(jti: str) -> bool:
    from app.database import SessionLocal
    from sqlalchemy import text

    try:
        async with SessionLocal() as db:
            row = await db.execute(
                text("SELECT exp_ts FROM revoked_token WHERE jti = :j"),
                {"j": jti},
            )
            exp = row.scalar()
            if exp is None:
                return False
            if exp < time.time():
                await db.execute(text("DELETE FROM revoked_token WHERE jti = :j"), {"j": jti})
                await db.commit()
                return False
            return True
    except Exception:  # noqa: BLE001 - 表未建等异常按未吊销处理
        return False


async def blacklist_token(jti: str, ttl_seconds: int) -> None:
    client = get_redis()
    exp_ts = time.time() + max(1, ttl_seconds)
    if client is not None:
        try:
            await client.set(f"bl:{jti}", "1", ex=max(1, ttl_seconds))
            return
        except Exception:
            pass
    try:
        await _sqlite_blacklist_upsert(jti, exp_ts)
        return
    except Exception:  # noqa: BLE001
        pass
    # 最终兜底：进程内存（重启失效，仅极端场景）
    _memory_blacklist[jti] = exp_ts


async def is_token_blacklisted(jti: str) -> bool:
    client = get_redis()
    if client is not None:
        try:
            return bool(await client.exists(f"bl:{jti}"))
        except Exception:
            pass
    if await _sqlite_blacklist_check(jti):
        return True
    exp = _memory_blacklist.get(jti)
    if exp is None:
        return False
    if exp < time.time():
        _memory_blacklist.pop(jti, None)
        return False
    return True


# ---------------------------------------------------------------------------
# 登录防爆破（5 次锁 15 分钟）
# ---------------------------------------------------------------------------
_memory_fail: dict[str, int] = {}
_memory_lock_until: dict[str, float] = {}


async def is_login_locked(username: str) -> bool:
    client = get_redis()
    if client is not None:
        try:
            count = await client.get(f"login:fail:{username}")
            return bool(count and int(count) >= LOGIN_MAX_FAIL)
        except Exception:
            pass
    until = _memory_lock_until.get(username)
    return until is not None and time.time() < until


async def record_login_failure(username: str) -> int:
    client = get_redis()
    if client is not None:
        try:
            count = await client.incr(f"login:fail:{username}")
            if count == 1:
                await client.expire(f"login:fail:{username}", LOGIN_LOCK_SECONDS)
            return int(count)
        except Exception:
            pass
    now = time.time()
    count = _memory_fail.get(username, 0) + 1
    _memory_fail[username] = count
    if count >= LOGIN_MAX_FAIL:
        _memory_lock_until[username] = now + LOGIN_LOCK_SECONDS
    return count


async def clear_login_failures(username: str) -> None:
    client = get_redis()
    if client is not None:
        try:
            await client.delete(f"login:fail:{username}")
        except Exception:
            pass
    _memory_fail.pop(username, None)
    _memory_lock_until.pop(username, None)
