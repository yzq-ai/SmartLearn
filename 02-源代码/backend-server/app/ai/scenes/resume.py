"""简历优化场景。"""
from __future__ import annotations
from app.ai.gateway import ai_gateway

async def optimize_resume(user_id: int, resume_text: str, job_jd: str | None = None) -> dict:
    query = f"简历内容：{resume_text}"
    if job_jd:
        query += f"\n目标岗位JD：{job_jd}"
    return await ai_gateway.process("RESUME", user_id, query)
