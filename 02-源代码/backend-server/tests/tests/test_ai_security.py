import logging

from app.services.ai_security import InMemoryRateLimiter, audit, redact_text


def test_redaction_removes_identifiers():
    safe = redact_text("联系 a@b.com 或 138-1234-5678，身份证号: 11010519490101123X")
    assert "a@b.com" not in safe
    assert "138-1234-5678" not in safe
    assert "11010519490101123X" not in safe
    assert "[email]" in safe and "[phone]" in safe


def test_limiter_is_per_user_and_sliding_window():
    limiter = InMemoryRateLimiter(limit=2, window_seconds=60)
    assert limiter.allow(1, now=100)
    assert limiter.allow(1, now=101)
    assert not limiter.allow(1, now=102)
    assert limiter.allow(2, now=102)
    assert limiter.allow(1, now=161)


def test_audit_has_structured_fields_without_text(caplog):
    with caplog.at_level(logging.INFO, logger="smartlearn.ai.audit"):
        audit("wrong_answer", 7, True)
    record = caplog.records[-1]
    assert record.scene == "wrong_answer"
    assert record.user == "7"
    assert record.blocked is True
    assert record.message == "ai_request"
