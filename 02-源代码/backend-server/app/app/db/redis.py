"""Optional Redis integration with graceful in-process fallback.

When ``REDIS_URL`` is empty or the Redis package is unavailable, every helper
returns ``None`` and callers fall back to process-local behaviour. This keeps
the local SQLite development/test path dependency-free while enabling
multi-worker rate limiting and distributed submit locks in production.
"""
from __future__ import annotations

import os
import uuid
from typing import Any

from app.core.config import settings

_redis: Any = None
_redis_tried = False


def get_redis():
    """Return a lazy async Redis client, or ``None`` when unavailable."""
    global _redis, _redis_tried
    if _redis_tried:
        return _redis
    _redis_tried = True
    if not settings.redis_url:
        return None
    try:
        import redis.asyncio as aioredis  # noqa: WPS433 - optional dependency
    except ImportError:
        return None
    try:
        _redis = aioredis.from_url(settings.redis_url, decode_responses=True)
    except Exception:
        _redis = None
    return _redis


class RedisLock:
    """Small ``SET key token NX EX`` lock with safe compare-and-delete release."""

    def __init__(self, client, key: str, ttl_seconds: int = 10):
        self.client = client
        self.key = key
        self.ttl_seconds = ttl_seconds
        self.token = uuid.uuid4().hex

    async def __aenter__(self) -> "RedisLock":
        acquired = await self.client.set(self.key, self.token, nx=True, ex=self.ttl_seconds)
        if not acquired:
            raise RuntimeError("lock_not_acquired")
        return self

    async def __aexit__(self, exc_type, exc, tb) -> None:
        script = (
            "if redis.call('get', KEYS[1]) == ARGV[1] then "
            "return redis.call('del', KEYS[1]) else return 0 end"
        )
        try:
            await self.client.eval(script, 1, self.key, self.token)
        except Exception:
            # The key expires on its own TTL; a failed release must not mask the
            # outcome of the wrapped operation.
            pass


async def acquire_submit_lock(exam_id: int, user_id: int) -> RedisLock | None:
    """Acquire a distributed submit lock, or ``None`` when Redis is absent."""
    client = get_redis()
    if client is None:
        return None
    return RedisLock(client, f"lock:exam:submit:{exam_id}:{user_id}", ttl_seconds=10)


class RedisRateLimiter:
    """Fixed-window rate limiter backed by Redis ``INCR`` + ``EXPIRE``."""

    def __init__(self, client, window_seconds: int = 60):
        self.client = client
        self.window_seconds = window_seconds

    async def allow(self, user_id: int, limit: int) -> bool:
        key = f"ratelimit:ai:{user_id}"
        try:
            current = await self.client.incr(key)
            if current == 1:
                await self.client.expire(key, self.window_seconds)
            return current <= limit
        except Exception:
            # Never let a Redis outage block the AI feature; fall back to allow.
            return True


def get_rate_limiter(window_seconds: int = 60) -> RedisRateLimiter | None:
    client = get_redis()
    if client is None:
        return None
    return RedisRateLimiter(client, window_seconds=window_seconds)
