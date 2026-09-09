"""错题分析场景。"""
from __future__ import annotations
from app.ai.gateway import ai_gateway

async def analyze_wrong(user_id: int, question: str, my_answer: str, correct_answer: str) -> dict:
    query = f"题目：{question}\n我的答案：{my_answer}\n正确答案：{correct_answer}"
    return await ai_gateway.process("WRONG_ANALYSIS", user_id, query)
