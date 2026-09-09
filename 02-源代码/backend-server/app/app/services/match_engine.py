"""岗位匹配规则引擎（纯函数，可复现、可单测）。

算法（对齐文档 6.5）：按岗位技能权重对个人技能分加权求和得到匹配度；
个人分 >= 60 视为已匹配标签，否则视为缺口标签。LLM 仅做解释，不改分数。

技能名归一：知识点命名（如「Python 基础」「FastAPI 路由」）与岗位技能命名
（如「Python」「FastAPI」）通过别名表统一到同一命名空间再匹配。
"""
from __future__ import annotations

from typing import Any


# 知识点 → 岗位技能 的别名映射（可按需扩充）
ALIAS_MAP: dict[str, str] = {
    "Python 基础": "Python",
    "FastAPI 路由": "FastAPI",
    "接口测试": "测试",
    "数据库接入": "MySQL",
    "SQL 基础": "SQL",
    "索引": "SQL",
    "事务": "SQL",
    "范式": "SQL",
    "复杂度": "算法",
    "线性表": "数据结构",
    "排序": "算法",
    "图论": "算法",
    "网络模型": "网络",
    "TCP-IP": "网络",
    "HTTP": "HTTP",
    "DNS": "网络",
    "进程管理": "操作系统",
    "内存管理": "操作系统",
    "文件系统": "操作系统",
    "IO调度": "操作系统",
}


def normalize_skill(name: str) -> str:
    """归一技能名：先查别名表，再做去空格/大小写处理。"""
    if name in ALIAS_MAP:
        return ALIAS_MAP[name]
    return name.strip()


def normalize_profile(profile_scores: dict[str, float]) -> dict[str, float]:
    """把画像技能键归一到岗位技能命名空间（同键取最大值）。"""
    out: dict[str, float] = {}
    for k, v in (profile_scores or {}).items():
        nk = normalize_skill(k)
        if nk not in out or float(v) > out[nk]:
            out[nk] = float(v)
    return out


def calc_match(
    profile_scores: dict[str, float],
    required: list[str],
    weights: dict[str, float] | None = None,
    threshold: float = 60.0,
) -> dict[str, Any]:
    required = [normalize_skill(t) for t in (required or [])]
    scores = normalize_profile(profile_scores)
    weights = weights or {}
    total_w = sum(float(weights.get(t, 1.0)) for t in required)
    if total_w <= 0:
        return {"match_score": 0.0, "matched_tags": [], "gap_tags": required}

    score = sum(float(scores.get(t, 0.0)) * float(weights.get(t, 1.0)) for t in required) / total_w
    matched = [t for t in required if float(scores.get(t, 0.0)) >= threshold]
    gaps = [t for t in required if float(scores.get(t, 0.0)) < threshold]
    return {"match_score": round(score, 1), "matched_tags": matched, "gap_tags": gaps}
