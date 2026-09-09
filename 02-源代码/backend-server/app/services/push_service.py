"""推送服务：AGC Push Kit 真实 HTTP 调用 + 日志占位回退。

``PUSH_BACKEND=log``（默认）仅记录日志；``PUSH_BACKEND=agc`` 且配置 AGC 凭据时，
通过 OAuth2 client_credentials 换取 token 后调用 Push Kit 消息下发接口。
"""
from __future__ import annotations

import json
import logging
import urllib.parse
import urllib.request

from app.core.config import settings

logger = logging.getLogger("smartlearn.push")


def _agc_configured() -> bool:
    return bool(settings.agc_client_id and settings.agc_client_secret and settings.agc_app_id)


def _agc_access_token() -> str | None:
    body = urllib.parse.urlencode({
        "grant_type": "client_credentials",
        "client_id": settings.agc_client_id,
        "client_secret": settings.agc_client_secret,
    }).encode()
    req = urllib.request.Request(settings.agc_token_url, data=body, headers={"Content-Type": "application/x-www-form-urlencoded"})
    with urllib.request.urlopen(req, timeout=10) as resp:
        return json.loads(resp.read()).get("access_token")


def _agc_send(token: str, title: str, content: str) -> bool:
    url = settings.agc_push_url.replace("{app_id}", settings.agc_app_id)
    payload = json.dumps({
        "message": {
            "notification": {"title": title, "body": content},
            "android": {"notification": {"click_action": {"type": 3}}},
            "token": [],
        }
    }).encode()
    req = urllib.request.Request(url, data=payload, headers={
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json",
    })
    with urllib.request.urlopen(req, timeout=10) as resp:
        return resp.status in (200, 201)


def send_push(user_ids: list[int], title: str, content: str) -> bool:
    if settings.push_backend == "agc" and _agc_configured():
        try:
            token = _agc_access_token()
            return _agc_send(token, title, content)
        except Exception as exc:  # noqa: BLE001 - 推送失败降级
            logger.warning("agc_push_failed", extra={"error": type(exc).__name__})
            return False
    if settings.push_backend == "log":
        logger.info("push_placeholder", extra={"users": user_ids, "title": title})
        return True
    logger.warning("push_backend_not_implemented", extra={"backend": settings.push_backend})
    return False


def check_push() -> dict:
    if settings.push_backend == "log":
        return {"configured": False, "reachable": False, "reason": "PUSH_BACKEND=log（占位）"}
    if not _agc_configured():
        return {"configured": False, "reachable": False, "reason": "未配置 AGC_CLIENT_ID/AGC_CLIENT_SECRET/AGC_APP_ID"}
    try:
        _agc_access_token()
        return {"configured": True, "reachable": True, "backend": "agc"}
    except Exception as exc:  # noqa: BLE001
        return {"configured": True, "reachable": False, "reason": type(exc).__name__}
