"""敏感词扫描（纯函数，可单测）。

对文本做大小写不敏感的包含匹配，返回命中的敏感词列表。生产环境可替换为
``ahocorasick-rs`` 的 AC 自动机以提升大批量吞吐，此处保持零额外依赖。
"""
from __future__ import annotations

from typing import Iterable


def scan_sensitive(text: str | None, words: Iterable[str]) -> list[str]:
    if not text:
        return []
    haystack = text.lower()
    hits: list[str] = []
    seen: set[str] = set()
    for word in words:
        needle = str(word or "").strip().lower()
        if not needle or needle in seen:
            continue
        seen.add(needle)
        if needle in haystack:
            hits.append(word.strip())
    return hits


_DEFAULT_SENSITIVE_WORDS: list[str] = [
    "暴力", "色情", "赌博", "毒品", "枪支", "自杀", "恐怖",
]


def scan_text(text: str | None, words: Iterable[str] | None = None) -> list[str]:
    """便捷封装：使用默认敏感词库调用 scan_sensitive。"""
    return scan_sensitive(text, words if words is not None else _DEFAULT_SENSITIVE_WORDS)
