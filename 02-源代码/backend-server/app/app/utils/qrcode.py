"""二维码生成工具（用于签到 HMAC 签名 token 可视化）。"""
from __future__ import annotations
import hashlib, hmac, time, logging

logger = logging.getLogger(__name__)

def generate_sign_token(task_id: int, secret: str, expire_seconds: int = 300) -> str:
    ts = str(int(time.time()))
    msg = f"{task_id}:{ts}"
    sig = hmac.new(secret.encode(), msg.encode(), hashlib.sha256).hexdigest()[:16]
    return f"{msg}:{sig}"

def verify_sign_token(token: str, secret: str, max_age: int = 300) -> bool:
    try:
        parts = token.split(":")
        if len(parts) != 3:
            return False
        task_id, ts, sig = parts
        expected = hmac.new(secret.encode(), f"{task_id}:{ts}".encode(), hashlib.sha256).hexdigest()[:16]
        if not hmac.compare_digest(sig, expected):
            return False
        age = time.time() - int(ts)
        return age <= max_age
    except Exception:
        return False
