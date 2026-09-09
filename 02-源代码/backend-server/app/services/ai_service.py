"""AI analysis with privacy-safe rule fallback and optional OpenAI-compatible LLM."""
from __future__ import annotations
import json
import os
import re
from typing import Any, Callable
from urllib import request

from app.services.ai_security import redact_text


def analyze_wrong_answer_rules(question: str, answer: str, correct_answer: str, subject: str | None = None) -> dict[str, Any]:
    """Pure, deterministic fallback; never sends input over the network."""
    if not answer.strip():
        category, analysis = "未作答", "本题没有检测到作答内容。"
    elif answer.strip().lower() == correct_answer.strip().lower():
        category, analysis = "非错题", "作答与参考答案一致，请继续巩固。"
    elif re.search(r"\d", answer) and not re.search(r"\d", correct_answer):
        category, analysis = "概念理解", "作答包含与题目要求不匹配的数值或步骤，可能混淆了概念。"
    else:
        category, analysis = "知识点掌握不牢", "作答与参考答案不一致，建议对照定义和解题步骤定位差异。"
    point = subject.strip() if subject and subject.strip() else "题目相关基础知识"
    return {"cause_category": category, "analysis": analysis, "suggestions": ["重新阅读题干并圈出关键词", "复习相关定义后独立重做", "记录本题错因并进行间隔复习"], "knowledge_points": [point], "source": "rules"}


# Backwards-compatible private alias used by existing callers/tests.
_redact = redact_text


def _llm_json(prompt: str) -> dict[str, Any] | list[Any] | None:
    from app.core.config import settings as cfg

    key = cfg.llm_api_key
    base = (cfg.llm_base_url or "https://api.openai.com/v1").rstrip("/")
    model = cfg.llm_model or "gpt-4o-mini"
    if not key:
        return None
    body = json.dumps({"model": model, "temperature": 0.2, "response_format": {"type": "json_object"}, "messages": [{"role": "system", "content": "仅输出JSON，不要复述个人身份信息。"}, {"role": "user", "content": prompt}]}).encode()
    req = request.Request(base + "/chat/completions", data=body, headers={"Authorization": "Bearer " + key, "Content-Type": "application/json"})
    try:
        with request.urlopen(req, timeout=20) as response:
            content = json.loads(response.read()).get("choices", [])[0].get("message", {}).get("content", "")
        return json.loads(content)
    except Exception:
        return None


def analyze_wrong_answer(payload: Any, llm: Callable[[str], Any] | None = None) -> dict[str, Any]:
    fallback = analyze_wrong_answer_rules(payload.question, payload.answer, payload.correct_answer, payload.subject)
    result = (llm or _llm_json)("分析错题并返回 cause_category, analysis, suggestions(数组), knowledge_points(数组)。题目:" + _redact(payload.question) + " 作答:" + _redact(payload.answer) + " 参考:" + _redact(payload.correct_answer))
    if isinstance(result, dict) and all(k in result for k in ("cause_category", "analysis", "suggestions", "knowledge_points")):
        return {**result, "source": "llm"}
    return fallback


def optimize_resume_rules(resume: str, target_role: str | None = None) -> list[dict[str, str]]:
    """Pure resume suggestions, preserving every original line."""
    items = []
    for line in resume.splitlines():
        original = line.strip()
        if not original:
            continue
        suggestion, reason, kind = original, "可补充量化结果或技术细节", "clarity"
        if len(original) < 12:
            suggestion = original + "（建议补充职责、方法与成果）"
            reason, kind = "信息较简略，难以体现贡献", "detail"
        elif not re.search(r"\d|提升|降低|负责|实现|完成", original):
            suggestion = original + "；补充可验证的业务结果和个人贡献"
            reason, kind = "缺少可量化成果", "impact"
        items.append({"original": original, "suggestion": suggestion, "reason": reason, "type": kind})
    return items


def optimize_resume(payload: Any, llm: Callable[[str], Any] | None = None) -> dict[str, Any]:
    fallback = {"items": optimize_resume_rules(payload.resume, payload.target_role), "source": "rules"}
    result = (llm or _llm_json)("逐条优化简历。返回JSON对象 {items:[{original,suggestion,reason,type}]}，必须保留original且不自动覆盖。目标岗位:" + _redact(payload.target_role or "未指定") + " 简历:" + _redact(payload.resume))
    if isinstance(result, dict) and isinstance(result.get("items"), list):
        valid = [x for x in result["items"] if isinstance(x, dict) and all(k in x for k in ("original", "suggestion", "reason", "type"))]
        if valid:
            return {"items": valid, "source": "llm"}
    return fallback


# ---------------------------------------------------------------------------
# 岗位推荐解释（规则引擎已算分，LLM 仅润色，数值必须原样出现）
# ---------------------------------------------------------------------------
def job_explain_rules(job_title: str, required_skills: list[str], match_score: float, matched_tags: list[str], gap_tags: list[str]) -> dict[str, Any]:
    matched = matched_tags or []
    gaps = gap_tags or []
    if matched and not gaps:
        explanation = f"你与「{job_title}」的匹配度为 {match_score} 分，核心技能 {('、'.join(matched))} 均达标，可重点关注岗位职责与项目经验匹配。"
    else:
        explanation = f"你与「{job_title}」的匹配度为 {match_score} 分，已满足 {('、'.join(matched) or '暂无')}；尚有 {('、'.join(gaps) or '若干')} 待提升。"
    suggestions = [f"补强「{g}」并做 1 个可展示项目" for g in gaps] or ["准备 2~3 个与岗位职责相关的项目案例", "熟悉岗位 JD 中的业务场景"]
    return {"explanation": explanation, "suggestions": suggestions[:3], "match_score": match_score, "source": "rules"}


def job_explain(payload: Any, llm: Callable[[str], Any] | None = None, extra_context: str = "") -> dict[str, Any]:
    fallback = job_explain_rules(payload.job_title, payload.required_skills, payload.match_score, payload.matched_tags, payload.gap_tags)
    prompt = (
        f"你是资深就业指导顾问。基于以下真实数据，向学生解释为什么推荐「{payload.job_title}」岗位，并给出可执行的提升建议。"
        f"{extra_context}"
        f"\n【匹配结果】匹配度 {payload.match_score} 分；已匹配技能 {payload.matched_tags}；待补技能 {payload.gap_tags}。"
        f"\n返回 JSON {{explanation, suggestions(数组)}}：explanation 必须引用匹配度数值 {payload.match_score} 和至少一项真实画像/JD 细节，120 字以内、具体不说套话；"
        f"suggestions 给 2~3 条结合该学生短板与 JD 要求的行动项。"
    )
    result = (llm or _llm_json)(prompt)
    if isinstance(result, dict) and isinstance(result.get("explanation"), str) and isinstance(result.get("suggestions"), list):
        return {"explanation": result["explanation"], "suggestions": result["suggestions"][:3], "match_score": payload.match_score, "source": "llm"}
    return fallback


# ---------------------------------------------------------------------------
# 内容摘要（纯压缩，低幻觉）
# ---------------------------------------------------------------------------
def summarize_rules(text: str) -> dict[str, Any]:
    sentences = [s.strip() for s in re.split(r"[。！？!?；;\n]", text) if s.strip()]
    if not sentences:
        return {"summary": "", "key_points": [], "source": "rules"}
    summary = "".join(sentences[:2])
    if len(summary) > 300:
        summary = summary[:300] + "…"
    points = sentences[:3]
    return {"summary": summary, "key_points": points, "source": "rules"}


def summarize(payload: Any, llm: Callable[[str], Any] | None = None) -> dict[str, Any]:
    fallback = summarize_rules(payload.text)
    result = (llm or _llm_json)("请把以下内容压缩为300字以内摘要并提炼3个要点，返回 {summary, key_points(数组)}：" + _redact(payload.text))
    if isinstance(result, dict) and isinstance(result.get("summary"), str) and isinstance(result.get("key_points"), list):
        return {**result, "source": "llm"}
    return fallback


# ---------------------------------------------------------------------------
# 学习计划（按弱项知识点与每日时长生成）
# ---------------------------------------------------------------------------
def generate_plan_rules(goal: str, daily_minutes: int, weak_kps: list[str], days: int) -> dict[str, Any]:
    kps = weak_kps or ["综合复习"]
    plan = []
    for i in range(days):
        day_kps = [kps[j % len(kps)] for j in range(i, i + 1)]
        per = max(10, daily_minutes // max(1, len(day_kps)))
        plan.append({"date": f"第{i + 1}天", "tasks": [{"kp": k, "minutes": per} for k in day_kps]})
    return {"plan": plan, "source": "rules"}


def generate_plan(payload: Any, llm: Callable[[str], Any] | None = None) -> dict[str, Any]:
    fallback = generate_plan_rules(payload.goal, payload.daily_minutes, payload.weak_kps, payload.days)
    result = (llm or _llm_json)(
        f"目标「{payload.goal}」，每日 {payload.daily_minutes} 分钟，弱项 {payload.weak_kps}，共 {payload.days} 天。"
        "返回 {plan:[{date,tasks:[{kp,minutes}]}]}。"
    )
    if isinstance(result, dict) and isinstance(result.get("plan"), list):
        return {**result, "source": "llm"}
    return fallback


# ---------------------------------------------------------------------------
# 面试模拟（≤8 轮追问 + 结束五维评分）
# ---------------------------------------------------------------------------
_INTERVIEW_QUESTIONS = [
    "请先做一个 1 分钟的自我介绍，突出与岗位相关的项目经验。",
    "你在这个项目里遇到过最大的技术难点是什么？如何解决？",
    "为什么选择这个岗位？你与它的匹配点是什么？",
    "讲一个你与团队协作中出现分歧并达成一致的例子。",
    "如果入职后前三个月，你会如何规划学习与交付？",
    "你如何应对时间紧、需求又不明确的任务？",
    "你的职业规划是什么？希望在未来 2~3 年达到什么状态？",
    "你还有什么问题想问我？",
]

_DIMENSIONS = ["表达清晰度", "专业深度", "逻辑性", "匹配度", "主动性"]


def interview_start_rules(job_title: str, required_skills: list[str]) -> dict[str, Any]:
    return {"question": _INTERVIEW_QUESTIONS[0], "turn": 1, "max_turns": 8}


def interview_turn_rules(job_title: str, question: str, answer: str, turn: int) -> dict[str, Any]:
    done = turn >= 8
    next_question = None if done else _INTERVIEW_QUESTIONS[min(turn, len(_INTERVIEW_QUESTIONS) - 1)]
    feedback = "回答结构清晰，建议补充量化成果以增强说服力。" if len(answer) >= 30 else "回答可以更具体，建议用 STAR 法则补充背景、行动与结果。"
    scores = None
    if done:
        base = 80.0 if len(answer) >= 40 else 70.0
        scores = {dim: base for dim in _DIMENSIONS}
    return {"feedback": feedback, "next_question": next_question, "done": done, "scores": scores}


# ---------------------------------------------------------------------------
# 题目生成（规则模板 + LLM，均进入 DRAFT）
# ---------------------------------------------------------------------------
def generate_questions_rules(kp_names: list[str], qtype: str, count: int, difficulty: int) -> list[dict[str, Any]]:
    kps = kp_names or ["基础知识"]
    out = []
    for i in range(count):
        kp = kps[i % len(kps)]
        qtype = qtype.upper()
        if qtype == "SINGLE":
            out.append({"type": "SINGLE", "content": f"关于「{kp}」，下列说法正确的是？", "options": ["A. 选项一", "B. 选项二", "C. 选项三", "D. 选项四"], "answer": "A", "analysis": f"本题考察 {kp} 的核心概念。", "difficulty": difficulty, "kp_names": [kp]})
        elif qtype == "MULTI":
            out.append({"type": "MULTI", "content": f"关于「{kp}」，下列哪些说法正确？", "options": ["A. 选项一", "B. 选项二", "C. 选项三", "D. 选项四"], "answer": "A,B", "analysis": f"本题考察 {kp} 的多点理解。", "difficulty": difficulty, "kp_names": [kp]})
        elif qtype == "JUDGE":
            out.append({"type": "JUDGE", "content": f"「{kp}」是相关领域的基础概念。", "options": None, "answer": "true", "analysis": f"本题判断 {kp} 相关陈述。", "difficulty": difficulty, "kp_names": [kp]})
        else:  # BLANK
            out.append({"type": "BLANK", "content": f"「{kp}」的核心要素是____。", "options": None, "answer": "核心概念", "analysis": f"本题填空 {kp} 的关键词。", "difficulty": difficulty, "kp_names": [kp]})
    return out


def generate_questions(payload: Any, llm: Callable[[str], Any] | None = None) -> dict[str, Any]:
    fallback_questions = generate_questions_rules(payload.kp_names, payload.type, payload.count, payload.difficulty)
    result = (llm or _llm_json)(
        f"命制 {payload.count} 道 {payload.type} 题，知识点 {payload.kp_names}，难度 {payload.difficulty}。"
        "返回 {questions:[{type,content,options,answer,analysis,difficulty,kp_names}]}，仅输出JSON。"
    )
    if isinstance(result, dict) and isinstance(result.get("questions"), list) and result["questions"]:
        return {"questions": result["questions"], "source": "llm"}
    return {"questions": fallback_questions, "source": "rules"}


# ---------------------------------------------------------------------------
# 课程问答（RAG）：检索课程资料 → 基于资料作答，无命中标注通用知识
# ---------------------------------------------------------------------------
def course_qa_rules(query: str, refs: list[dict]) -> dict[str, Any]:
    if not refs:
        return {
            "answer": "未在课程资料中找到直接相关的内容。以下建议基于通用知识：请先复习课程相关章节，再对照教材或课件定位该知识点。",
            "refs": [],
            "grounded": False,
            "source": "rules",
        }
    top = refs[0]
    answer = f"根据课程资料「{top['source']}」：{top['snippet']}"
    return {"answer": answer, "refs": refs, "grounded": True, "source": "rules"}


def course_qa(query: str, refs: list[dict], llm: Callable[[str], Any] | None = None) -> dict[str, Any]:
    fallback = course_qa_rules(query, refs)
    if not refs:
        return fallback
    context = "\n".join([f"[{r['source']}] {r['snippet']}" for r in refs])
    result = (llm or _llm_json)(
        f"仅根据以下课程资料回答问题，资料未覆盖时明确说明。返回 {{answer, grounded(bool)}}。\n资料：{_redact(context)}\n问题：{_redact(query)}"
    )
    if isinstance(result, dict) and isinstance(result.get("answer"), str):
        return {"answer": result["answer"], "refs": refs, "grounded": bool(result.get("grounded", True)), "source": "llm"}
    return fallback
