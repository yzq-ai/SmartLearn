"""面试模拟场景。"""
from __future__ import annotations
from app.ai.gateway import ai_gateway

async def interview_turn(user_id: int, job_title: str, question: str | None = None, answer: str | None = None, turn: int = 1) -> dict:
    query = f"岗位：{job_title}，第{turn}轮"
    if question and answer:
        query += f"\n面试官问题：{question}\n我的回答：{answer}"
    return await ai_gateway.process("INTERVIEW", user_id, query)
