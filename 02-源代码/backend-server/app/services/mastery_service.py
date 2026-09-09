"""掌握度与画像计算（纯函数）。"""
from __future__ import annotations

from typing import Any, Iterable


def calc_mastery_pct(correct_cnt: int, total_cnt: int) -> float:
    """掌握度 = 加权正确率，无作答时返回 0。"""
    if total_cnt <= 0:
        return 0.0
    return round(correct_cnt / total_cnt * 100, 2)


def build_skill_scores(kp_masteries: Iterable[dict], kp_names: dict[int, str]) -> dict[str, float]:
    """把知识点掌握度聚合为技能分。

    每个知识点映射为一个同名技能；同一技能下多个知识点取均值。
    ``kp_masteries`` 每项含 ``kp_id`` / ``correct_cnt`` / ``total_cnt``。
    """
    agg: dict[str, list[float]] = {}
    for row in kp_masteries:
        name = kp_names.get(row["kp_id"])
        if not name:
            continue
        pct = calc_mastery_pct(row["correct_cnt"], row["total_cnt"])
        agg.setdefault(name, []).append(pct)
    return {name: round(sum(v) / len(v), 2) for name, v in agg.items()}


def build_radar_data(skill_scores: dict[str, float]) -> dict[str, float]:
    """六维雷达：取技能分前 6 项补齐为六维（缺项用 60 基线）。"""
    dims = ["专业基础", "工程实践", "数据结构", "数据库", "算法思维", "求职匹配"]
    ordered = sorted(skill_scores.items(), key=lambda kv: kv[1], reverse=True)
    values = [v for _k, v in ordered]
    radar = {}
    for i, dim in enumerate(dims):
        radar[dim] = values[i] if i < len(values) else 60.0
    return radar
