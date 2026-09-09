import pytest

from app.services.grading import grade_blank, grade_exam, grade_multi, grade_question


def test_single_exact_match():
    assert grade_question("SINGLE", "A", "A", 10) == 10
    assert grade_question("SINGLE", "B", "A", 10) == 0


def test_judge_ignores_case_and_space():
    assert grade_question("JUDGE", " True ", "true", 10) == 10
    assert grade_question("JUDGE", "FALSE", "true", 10) == 0


def test_multi_full_match_and_wrong_selection():
    assert grade_multi(["A", "C"], "A,C", 10) == 10
    # 错选 -> 0
    assert grade_multi(["A", "D"], "A,C", 10) == 0
    # 漏选 -> 部分分（默认 50%）
    assert grade_multi(["A"], "A,C", 10) == 5


def test_multi_string_answers_are_equivalent():
    assert grade_multi("A|C", "A,C", 10) == 10


def test_blank_proportional_multi_blank():
    assert grade_blank("uvicorn", "uvicorn", 10) == 10
    assert grade_blank("uvicorn|||error", "uvicorn|||fastapi", 10) == 5
    # 忽略首尾空格
    assert grade_blank(" uvicorn |||fastapi", "uvicorn|||fastapi", 10) == 10


def test_short_returns_none_for_teacher_grading():
    assert grade_question("SHORT", "任何答案", "", 20) is None


def test_grade_exam_aggregates_and_flags_subjective():
    questions = [
        {"id": 1, "type": "SINGLE", "answer": "A", "score": 50},
        {"id": 2, "type": "JUDGE", "answer": "true", "score": 50},
    ]
    result = grade_exam(questions, {1: "A", 2: "true"})
    assert result["score"] == 100
    assert result["total"] == 100
    assert result["has_subjective"] is False
    assert all(d["correct"] for d in result["details"])

    subjective = grade_exam([{"id": 3, "type": "SHORT", "answer": "", "score": 20}], {3: "x"})
    assert subjective["has_subjective"] is True
    assert subjective["score"] == 0
