"""Unified business exception and global error envelope.

Every error is returned as ``{code, message, data: null}`` so clients have one
stable shape regardless of whether the failure came from business rules,
HTTP-level validation, or FastAPI request validation.
"""
from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from starlette.exceptions import HTTPException as StarletteHTTPException

# Map common HTTP statuses to the project's business error codes (see the
# design doc section 8.1). Unknown statuses fall back to the status itself.
_STATUS_CODE_MAP = {
    401: 1001,
    403: 1002,
    404: 1003,
    423: 1004,
    422: 2001,
    409: 3004,
    410: 3001,
    429: 3003,
    503: 5001,
}


class BizError(Exception):
    """Business error with an application error code and optional HTTP status."""

    def __init__(self, code: int, message: str, http_status: int = 200):
        self.code = code
        self.message = message
        self.http_status = http_status
        super().__init__(message)


def register_exception_handlers(app: FastAPI) -> None:
    @app.exception_handler(BizError)
    async def biz_error_handler(_request: Request, exc: BizError) -> JSONResponse:
        return JSONResponse(
            status_code=exc.http_status,
            content={"code": exc.code, "message": exc.message, "data": None},
        )

    @app.exception_handler(StarletteHTTPException)
    async def http_error_handler(_request: Request, exc: StarletteHTTPException) -> JSONResponse:
        code = _STATUS_CODE_MAP.get(exc.status_code, exc.status_code)
        headers = getattr(exc, "headers", None)
        return JSONResponse(
            status_code=exc.status_code,
            content={"code": code, "message": str(exc.detail), "data": None},
            headers=headers,
        )

    @app.exception_handler(RequestValidationError)
    async def validation_error_handler(_request: Request, exc: RequestValidationError) -> JSONResponse:
        return JSONResponse(
            status_code=422,
            content={"code": 2001, "message": "参数校验失败", "data": _serializable_errors(exc)},
        )


def _serializable_errors(exc: RequestValidationError) -> list[dict]:
    """将校验错误转为可 JSON 序列化的结构（pydantic v2 的 ctx 含异常对象）。"""
    cleaned: list[dict] = []
    for err in exc.errors():
        item = {
            "loc": [str(part) for part in err.get("loc", [])],
            "msg": err.get("msg", ""),
            "type": err.get("type", ""),
        }
        ctx = err.get("ctx")
        if isinstance(ctx, dict):
            item["ctx"] = {k: str(v) for k, v in ctx.items()}
        cleaned.append(item)
    return cleaned
