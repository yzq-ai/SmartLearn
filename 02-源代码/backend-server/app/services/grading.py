"""五种题型判分器（纯函数，100% 单测覆盖）。

题型规则（对齐文档 6.4）：
- SINGLE 单选：答案精确匹配得满分，否则 0。
- MULTI  多选：全对满分；漏选按比例给分（默认 50%）；错选或空 0。
- JUDGE  判断：精确匹配（忽略首尾空格、大小写）。
- BLANK  填空：多空以 ``|||`` 分隔，按空位匹配比例给分，忽略首尾空格。
- SHORT  简答：返回 ``None`` 表示需教师批改，AI 参考分不终裁。
"""
from __future__ import annotations

from typing import Any, Iterable


def _norm_text(value: Any) -> str:
    if value is None:
        return ""
    return str(value).strip().lower()


def _split_multi(value: Any) -> set[str]:
    """多选答案拆分为有序无关的选项集合，支持 A,B / A|B / ["A","B"]。"""
    if value is None:
        return set()
    if isinstance(value, (list, tuple, set)):
        return {_norm_text(v) for v in value if _norm_text(v)}
    text = str(value)
    if not text.strip():
        return set()
    # 逗号、竖线、顿号都作为分隔符；单个字母直接作为一项。
    if any(sep in text for sep in (",", "|", "、", "；", ";")):
        import re
        return {p.strip().lower() for p in re.split(r"[,|、；;]+", text) if p.strip()}
    return {_norm_text(text)}


def grade_single(student: Any, correct: Any, score: float, **_kw: Any) -> float:
    return float(score) if _norm_text(student) == _norm_text(correct) else 0.0


def grade_judge(student: Any, correct: Any, score: float, **_kw: Any) -> float:
    return float(score) if _norm_text(student) == _norm_text(correct) else 0.0


def grade_multi(student: Any, correct: Any, score: float, partial: float = 0.5, **_kw: Any) -> float:
    student_set = _split_multi(student)
    correct_set = _split_multi(correct)
    if not correct_set:
        return 0.0
    if student_set == correct_set:
        return float(score)
    # 漏选：学生答案是非空真子集且无错选。
    if student_set and student_set < correct_set:
        return float(score) * float(partial)
    return 0.0


def grade_blank(student: Any, correct: Any, score: float, **_kw: Any) -> float:
    if correct is None:
        return 0.0
    correct_parts = [p.strip().lower() for p in str(correct).split("|||") if p.strip()]
    if not correct_parts:
        return 0.0
    student_parts = [p.strip().lower() for p in str(student).split("|||") if p.strip()] if student is not None else []
    matched = 0
    for idx, cpart in enumerate(correct_parts):
        spart = student_parts[idx] if idx < len(student_parts) else ""
        if spart == cpart:
            matched += 1
    return float(score) * matched / len(correct_parts)


def grade_short(_student: Any, _correct: Any, _score: float, **_kw: Any) -> float | None:
    return None


_GRADERS = {
    "SINGLE": grade_single,
    "MULTI": grade_multi,
    "JUDGE": grade_judge,
    "BLANK": grade_blank,
    "SHORT": grade_short,
}


def grade_question(qtype: str, student: Any, correct: Any, score: float, **options: Any) -> float | None:
    """按题型判分。``SHORT`` 返回 ``None`` 表示主观题待批改。"""
    grader = _GRADERS.get(str(qtype or "").upper(), grade_single)
    return grader(student, correct, score, **options)


def grade_exam(
    questions: Iterable[dict],
    answers: dict[int, Any],
    multi_partial: float = 0.5,
) -> dict:
    """对整卷判分。

    ``questions`` 每项需含 ``id`` / ``type`` / ``answer`` / ``score``。
    ``answers`` 为 ``{question_id: student_answer}``。
    返回 ``{score, total, objective_score, details, has_subjective}``。
    """
    details: list[dict] = []
    score = 0.0
    total = 0.0
    objective_total = 0.0
    has_subjective = False
    for q in questions:
        qid = q["id"]
        qtype = str(q.get("type", "SINGLE")).upper()
        qscore = float(q.get("score") or 0)
        total += qscore
        student = answers.get(qid)
        if qtype == "SHORT":
            has_subjective = True
            details.append({"question_id": qid, "correct": None, "earned": None, "score": qscore})
            continue
        earned = grade_question(qtype, student, q.get("answer"), qscore, partial=multi_partial)
        earned = 0.0 if earned is None else float(earned)
        score += earned
        objective_total += qscore
        details.append({"question_id": qid, "correct": earned >= qscore, "earned": earned, "score": qscore})
    return {
        "score": score,
        "total": total,
        "objective_score": score,
        "details": details,
        "has_subjective": has_subjective,
    }
