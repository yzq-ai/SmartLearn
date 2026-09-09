"""Small, process-local controls shared by AI endpoints."""
from __future__ import annotations

import logging
import re
import threading
import time
from collections import defaultdict, deque

logger = logging.getLogger("smartlearn.ai.audit")

# Keep this deliberately conservative: these values are useful in logs/prompts,
# while the original user text must never be emitted by this module.
_EMAIL = re.compile(r"[\w.+-]+@[\w.-]+\.[A-Za-z]{2,}")
_PHONE = re.compile(r"(?<!\d)(?:\+?\d[\d\s-]{7,}\d)(?!\d)")
_ID = re.compile(r"(?:身份证|身份证号)\s*[:：]?\s*[0-9Xx-]+")


def redact_text(value: object) -> str:
    """Return text safe for an external prompt or diagnostic metadata."""
    text = "" if value is None else str(value)
    text = _EMAIL.sub("[email]", text)
    text = _PHONE.sub("[phone]", text)
    return _ID.sub("身份证号:[redacted]", text)


class InMemoryRateLimiter:
    """Fixed-window-ish sliding limiter, safe for FastAPI worker threads."""

    def __init__(self, limit: int = 10, window_seconds: float = 60.0):
        self.limit = max(1, int(limit))
        self.window_seconds = float(window_seconds)
        self._events: dict[int, deque[float]] = defaultdict(deque)
        self._lock = threading.Lock()

    def allow(self, user_id: int, now: float | None = None) -> bool:
        current = time.monotonic() if now is None else now
        with self._lock:
            events = self._events[user_id]
            cutoff = current - self.window_seconds
            while events and events[0] <= cutoff:
                events.popleft()
            if len(events) >= self.limit:
                return False
            events.append(current)
            return True

    def clear(self) -> None:
        with self._lock:
            self._events.clear()


def audit(scene: str, user_id: object, blocked: bool) -> None:
    """Emit structured audit fields only; never include request text."""
    logger.info("ai_request", extra={"scene": scene, "user": str(user_id), "blocked": bool(blocked)})


def desensitize_input(text: str) -> str:
    """端云双重脱敏入口：正则替换手机号/邮箱/身份证 + 敏感词扫描。"""
    import re as _re
    text = _EMAIL.sub("[email]", text)
    text = _PHONE.sub("[phone]", text)
    text = _ID.sub("身份证号:[redacted]", text)
    try:
        from app.services.sensitive import scan_text
        hits = scan_text(text)
        for word in hits:
            text = text.replace(word, "[敏感词]")
    except Exception:
        pass
    return text


def check_output_safety(text: str) -> bool:
    """输出安全检查：含敏感词则不通过。"""
    try:
        from app.services.sensitive import scan_text
        hits = scan_text(text)
        return len(hits) == 0
    except Exception:
        return True
