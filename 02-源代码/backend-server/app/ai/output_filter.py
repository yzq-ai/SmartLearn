"""输出过滤：敏感词扫描 + JSON Schema 校验。"""
from __future__ import annotations
import json
from app.services.sensitive import scan_text

def filter_output(text: str) -> tuple[str, bool]:
    hits = scan_text(text)
    if hits:
        for word in hits:
            text = text.replace(word, "***")
        return text, True
    return text, False

def validate_json_schema(text: str, required_keys: list[str]) -> bool:
    try:
        data = json.loads(text)
        if isinstance(data, list):
            return all(isinstance(item, dict) and all(k in item for k in required_keys) for item in data)
        if isinstance(data, dict):
            return all(k in data for k in required_keys)
        return False
    except (json.JSONDecodeError, TypeError):
        return False
