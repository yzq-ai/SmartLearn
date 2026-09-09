"""端云双重脱敏：正则 + AC 自动机扫描姓名/学号/手机号/身份证。"""
from __future__ import annotations
import re
from app.services.sensitive import scan_text

_PATTERNS = [
    (re.compile(r"1[3-9]\d{9}"), "[手机号]"),
    (re.compile(r"\d{17}[\dXx]"), "[身份证]"),
    (re.compile(r"stu_\d+"), "[学号]"),
]

def desensitize(text: str) -> str:
    for pattern, replacement in _PATTERNS:
        text = pattern.sub(replacement, text)
    hits = scan_text(text)
    if hits:
        for word in hits:
            text = text.replace(word, "[敏感词]")
    return text

def check_output(text: str) -> bool:
    hits = scan_text(text)
    return len(hits) == 0
