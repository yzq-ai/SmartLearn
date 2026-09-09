"""课程问答 RAG 场景。"""
from __future__ import annotations
from app.ai.gateway import ai_gateway

async def course_qa(user_id: int, query: str, course_id: int | None = None) -> dict:
    return await ai_gateway.process("COURSE_QA", user_id, query, course_id=course_id)
