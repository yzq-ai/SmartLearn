"""题目生成场景（强制审核流）。"""
from __future__ import annotations
from app.ai.gateway import ai_gateway

async def generate_questions(user_id: int, kp_names: list[str], qtype: str, count: int, difficulty: int = 3) -> dict:
    query = f"知识点：{', '.join(kp_names)}；题型：{qtype}；数量：{count}；难度：{difficulty}"
    return await ai_gateway.process("QUESTION_GEN", user_id, query)
