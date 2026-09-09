"""限流中间件：Redis 分布式限流（连接复用），无 Redis 时进程内滑动窗口降级。"""
from __future__ import annotations

import logging
import os
import time
from collections import defaultdict, deque

from starlette.middleware.base import BaseHTTPMiddleware, RequestResponseEndpoint
from starlette.requests import Request
from starlette.responses import JSONResponse, Response

logger = logging.getLogger(__name__)

# 进程内滑动窗口（单实例部署/演示环境兜底，多实例请配置 REDIS_URL）
_window: dict[str, deque] = defaultdict(deque)
_WINDOW_SECONDS = 60


class RateLimitMiddleware(BaseHTTPMiddleware):
    def __init__(self, app, requests_per_minute: int = 120):
        super().__init__(app)
        self.rpm = requests_per_minute
        self._redis = None
        self._redis_tried = False

    def _get_redis(self):
        """惰性建连一次并复用；失败自动降级进程内窗口。"""
        if self._redis_tried:
            return self._redis
        self._redis_tried = True
        from app.core.config import settings
        if not settings.redis_url:
            return None
        try:
            import redis.asyncio as aioredis

            self._redis = aioredis.from_url(settings.redis_url, decode_responses=True)
        except Exception as exc:  # noqa: BLE001
            logger.warning("Redis 连接失败，限流降级为进程内窗口: %s", exc)
            self._redis = None
        return self._redis

    async def dispatch(self, request: Request, call_next: RequestResponseEndpoint) -> Response:
        # 显式关闭限流（本地压测/CI 场景）
        from app.core.config import settings
        if os.environ.get("RATE_LIMIT_DISABLED") == "1":
            return await call_next(request)

        client_key = request.client.host if request.client else "unknown"
        path = request.url.path
        # 健康探针与文档不限流
        if path in ("/health", "/health/ready", "/docs", "/openapi.json"):
            return await call_next(request)

        r = self._get_redis()
        if r is not None:
            try:
                key = f"ratelimit:{client_key}"
                current = await r.incr(key)
                if current == 1:
                    await r.expire(key, _WINDOW_SECONDS)
                if current > self.rpm:
                    return JSONResponse(
                        {"code": 429, "message": "请求过于频繁，请稍后再试", "data": None},
                        status_code=429,
                    )
            except Exception as exc:  # noqa: BLE001
                logger.warning("分布式限流异常，本次放行: %s", exc)
            return await call_next(request)

        # 进程内滑动窗口
        now = time.monotonic()
        bucket = _window[client_key]
        while bucket and now - bucket[0] > _WINDOW_SECONDS:
            bucket.popleft()
        if len(bucket) >= self.rpm:
            return JSONResponse(
                {"code": 429, "message": "请求过于频繁，请稍后再试", "data": None},
                status_code=429,
            )
        bucket.append(now)
        # 防 key 泄漏
        if len(_window) > 10000:
            for stale in [k for k, v in _window.items() if not v]:
                _window.pop(stale, None)
        return await call_next(request)
