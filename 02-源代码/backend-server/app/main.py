from contextlib import asynccontextmanager

import logging

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.core.config import settings
from app.core.exceptions import register_exception_handlers
from app.database import init_db
from app.middleware.request_id import RequestIdMiddleware
from app.middleware.audit_middleware import AuditMiddleware
from app.middleware.rate_limit import RateLimitMiddleware

logger = logging.getLogger("smartlearn.startup")


@asynccontextmanager
async def lifespan(_app: FastAPI):
    await init_db()
    risks = settings.security_risks()
    if risks:
        for item in risks:
            logger.warning("⚠ 安全体检: %s", item)
    else:
        logger.info("✓ 安全体检通过：JWT_SECRET/CORS/DATABASE 均为生产配置")
    logger.info("SmartLearn backend started (LLM=%s, storage=%s)",
                settings.llm_model,
                "OBS" if (settings.obs_bucket and settings.obs_ak) else f"local:{settings.local_storage_dir}")
    yield


from app.api.v1 import all_routers

app = FastAPI(
    title="SmartLearn Backend",
    version="1.0.0",
    description="SmartLearn async FastAPI backend",
    lifespan=lifespan,
)

app.add_middleware(RateLimitMiddleware)
app.add_middleware(AuditMiddleware)
app.add_middleware(RequestIdMiddleware)
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origin_list,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

register_exception_handlers(app)

for r in all_routers:
    app.include_router(r, prefix="/api/v1")


@app.get("/health", tags=["system"])
async def health():
    """存活探针（k8s liveness）：进程可响应即 OK。"""
    return {"status": "ok", "service": "smartlearn-backend", "version": app.version}


@app.get("/health/ready", tags=["system"])
async def health_ready():
    """就绪探针（k8s readiness）：数据库真实连通 + 存储可写 + 风险项暴露。"""
    checks: dict[str, bool | str] = {}
    try:
        from sqlalchemy import text
        from app.database import engine
        async with engine.connect() as conn:
            await conn.execute(text("SELECT 1"))
        checks["database"] = True
    except Exception as exc:  # noqa: BLE001
        checks["database"] = f"down: {type(exc).__name__}"
    try:
        from app.services.local_store import storage_dir, storage_usage_bytes
        storage_dir()
        checks["storage"] = f"ok ({storage_usage_bytes() // 1024}KB)"
    except Exception as exc:  # noqa: BLE001
        checks["storage"] = f"down: {type(exc).__name__}"
    checks["llm_configured"] = bool(settings.llm_api_key)
    checks["security_risks"] = len(settings.security_risks())
    healthy = checks.get("database") is True
    return {"status": "ok" if healthy else "degraded", "checks": checks}
