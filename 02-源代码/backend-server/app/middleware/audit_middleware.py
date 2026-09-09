"""审计中间件：记录所有写操作到 sys_audit_log。"""
from __future__ import annotations
import time, logging
from starlette.middleware.base import BaseHTTPMiddleware, RequestResponseEndpoint
from starlette.requests import Request
from starlette.responses import Response

logger = logging.getLogger(__name__)

class AuditMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next: RequestResponseEndpoint) -> Response:
        start = time.time()
        response = await call_next(request)
        duration_ms = int((time.time() - start) * 1000)
        if request.method in ("POST", "PUT", "PATCH", "DELETE"):
            logger.info("AUDIT method=%s path=%s status=%d duration=%dms", request.method, request.url.path, response.status_code, duration_ms)
        return response
