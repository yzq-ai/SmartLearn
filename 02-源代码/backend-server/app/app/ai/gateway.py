"""AI 网关：限流→双重脱敏→场景路由→RAG→Prompt→LLM→输出过滤→审计→降级。"""
from __future__ import annotations
import time
import json
import logging
from typing import Any

from app.core.config import settings
from app.services import ai_service
from app.services.ai_security import desensitize_input, check_output_safety, InMemoryRateLimiter, audit
from app.services.sensitive import scan_text
from app.services.vector_store import get_vector_store

logger = logging.getLogger(__name__)


class AIGateway:
    def __init__(self):
        self._limiter = InMemoryRateLimiter(limit=10, window_seconds=60.0)

    async def process(self, scene: str, user_id: int, query: str, **kwargs: Any) -> dict[str, Any]:
        start = time.time()

        if not self._limiter.allow(user_id):
            audit(scene, user_id, blocked=True)
            return {"output": "请求过于频繁，请稍后再试", "blocked": True}

        try:
            safe_query = desensitize_input(query)
            rag_refs: list[dict] = []

            if scene == "COURSE_QA":
                vs = get_vector_store()
                rag_refs = vs.search([], safe_query, top_k=4)

            raw_output = self._dispatch(scene, safe_query, rag_refs, **kwargs)

            if not check_output_safety(raw_output):
                audit(scene, user_id, blocked=True)
                return {"output": "内容安全检查未通过，请调整提问后重试", "blocked": True}

            audit(scene, user_id, blocked=False)
            latency_ms = int((time.time() - start) * 1000)
            return {"output": raw_output, "refs": rag_refs, "latency_ms": latency_ms, "blocked": False}
        except Exception as e:
            logger.warning("AI gateway fallback: %s", e)
            return {"output": self._fallback(scene, query), "fallback": True}

    def _dispatch(self, scene: str, query: str, refs: list[dict], **kwargs: Any) -> str:
        if scene == "COURSE_QA":
            result = ai_service.course_qa(query, refs)
            return str(result.get("answer", ""))
        if scene == "SUMMARY":
            result = ai_service.summarize(type("P", (), {"text": query})())
            return str(result.get("summary", ""))
        if scene == "PLAN":
            result = ai_service.generate_plan(type("P", (), {
                "goal": kwargs.get("goal", ""),
                "daily_minutes": kwargs.get("daily_minutes", 30),
                "weak_kps": kwargs.get("weak_kps", []),
                "days": kwargs.get("days", 7),
            })())
            return json.dumps(result, ensure_ascii=False)
        if scene == "QUESTION_GEN":
            result = ai_service.generate_questions(type("P", (), {
                "kp_names": kwargs.get("kp_names", []),
                "type": kwargs.get("qtype", "SINGLE"),
                "count": kwargs.get("count", 5),
                "difficulty": kwargs.get("difficulty", 3),
            })())
            return json.dumps(result, ensure_ascii=False)
        if scene == "WRONG_ANALYSIS":
            result = ai_service.analyze_wrong_answer(type("P", (), {
                "question": kwargs.get("question", ""),
                "answer": kwargs.get("answer", ""),
                "correct_answer": kwargs.get("correct_answer", ""),
                "subject": kwargs.get("subject", ""),
            })())
            return json.dumps(result, ensure_ascii=False)
        if scene == "RESUME":
            result = ai_service.optimize_resume(type("P", (), {
                "resume": query,
                "target_role": kwargs.get("target_role", ""),
            })())
            return json.dumps(result, ensure_ascii=False)
        if scene == "JOB_EXPLAIN":
            result = ai_service.job_explain(type("P", (), {
                "job_title": kwargs.get("job_title", ""),
                "required_skills": kwargs.get("required_skills", []),
                "match_score": kwargs.get("match_score", 0.0),
                "matched_tags": kwargs.get("matched_tags", []),
                "gap_tags": kwargs.get("gap_tags", []),
            })())
            return json.dumps(result, ensure_ascii=False)
        if scene == "INTERVIEW":
            turn = kwargs.get("turn", 1)
            if turn <= 1:
                result = ai_service.interview_start_rules(
                    kwargs.get("job_title", ""), kwargs.get("required_skills", []),
                )
            else:
                result = ai_service.interview_turn_rules(
                    kwargs.get("job_title", ""),
                    kwargs.get("question", ""),
                    query,
                    turn,
                )
            return json.dumps(result, ensure_ascii=False)
        return query

    def _fallback(self, scene: str, query: str) -> str:
        fallbacks = {
            "COURSE_QA": "暂无法回答，请查阅课程资料或稍后再试。",
            "SUMMARY": "摘要生成暂时不可用，请稍后再试。",
            "PLAN": "学习计划生成暂时不可用，请稍后再试。",
            "QUESTION_GEN": "题目生成暂时不可用，请稍后再试。",
            "WRONG_ANALYSIS": "错题分析暂时不可用，请稍后再试。",
            "RESUME": "简历优化暂时不可用，请稍后再试。",
            "JOB_EXPLAIN": "岗位解释暂时不可用，请稍后再试。",
            "INTERVIEW": "面试模拟暂时不可用，请稍后再试。",
        }
        return fallbacks.get(scene, "AI 服务暂时不可用，请稍后再试。")


ai_gateway = AIGateway()
