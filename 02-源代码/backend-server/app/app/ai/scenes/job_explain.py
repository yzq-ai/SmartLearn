"""岗位推荐解释场景。"""
from __future__ import annotations
from app.ai.gateway import ai_gateway

async def explain_job(user_id: int, job_title: str, match_score: float, matched_tags: list[str], gap_tags: list[str]) -> dict:
    query = f"岗位：{job_title}，匹配度：{match_score}，已匹配：{matched_tags}，待提升：{gap_tags}"
    return await ai_gateway.process("JOB_EXPLAIN", user_id, query)
