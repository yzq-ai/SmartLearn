"""轻量知识库检索（RAG 兜底）。

无外部向量库时，用关键词命中率对课程小节内容做排序检索，返回与查询最相关
的片段。生产可替换为 bge-large-zh Embedding + Milvus/Qdrant 向量检索。
"""
from __future__ import annotations

import re
from typing import Iterable

_ASCII_TOKEN = re.compile(r"[a-zA-Z0-9]+")
_CN_RUN = re.compile(r"[\u4e00-\u9fff]+")


def tokenize(text: str | None) -> set[str]:
    """分词：ASCII 单词整体保留，中文按相邻两字二元组切分（无分词器时的轻量近似）。"""
    if not text:
        return set()
    tokens: set[str] = {token.lower() for token in _ASCII_TOKEN.findall(text)}
    for run in _CN_RUN.findall(text):
        if len(run) == 1:
            tokens.add(run)
        else:
            for i in range(len(run) - 1):
                tokens.add(run[i:i + 2])
    return tokens


def keyword_score(passage: str, query_tokens: set[str]) -> float:
    """按查询关键词命中比例给片段打分（0~1）。"""
    if not query_tokens:
        return 0.0
    passage_tokens = tokenize(passage)
    overlap = len(passage_tokens & query_tokens)
    return overlap / len(query_tokens)


def retrieve_top(
    passages: Iterable[dict],
    query: str,
    top_k: int = 4,
    min_score: float = 0.1,
) -> list[dict]:
    """从 ``passages``（每项含 ``content``/``source``）检索最相关的 top_k 条。

    返回按得分降序、得分不低于 ``min_score`` 的片段列表，每项含 ``source``/``snippet``。
    """
    query_tokens = tokenize(query)
    scored = []
    for passage in passages:
        content = passage.get("content") or ""
        score = keyword_score(content, query_tokens)
        if score >= min_score:
            scored.append((score, passage))
    scored.sort(key=lambda item: item[0], reverse=True)
    results = []
    for score, passage in scored[:top_k]:
        snippet = (passage.get("content") or "")[:200]
        results.append({"source": passage.get("source") or "课程资料", "snippet": snippet})
    return results
