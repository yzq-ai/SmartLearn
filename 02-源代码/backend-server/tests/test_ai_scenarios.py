import uuid

import pytest
from httpx import ASGITransport, AsyncClient

from app.main import app
from app.services.ai_service import (
    generate_plan_rules,
    generate_questions_rules,
    interview_turn_rules,
    job_explain_rules,
    summarize_rules,
)


@pytest.fixture
async def client():
    async with app.router.lifespan_context(app):
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as http:
            yield http


async def login(client, username="student", password="1015401x"):
    resp = await client.post("/api/v1/auth/login", json={"username": username, "password": password})
    assert resp.status_code == 200
    return {"Authorization": f"Bearer {resp.json()['data']['access_token']}"}


# ---------------------------------------------------------------------------
# 纯函数规则兜底
# ---------------------------------------------------------------------------
def test_job_explain_rules_preserves_score():
    result = job_explain_rules("后端实习生", ["Python", "MySQL"], 74.5, ["Python", "MySQL"], [])
    assert result["match_score"] == 74.5
    assert "74.5" in result["explanation"]


def test_summary_rules_extracts_key_points():
    text = "第一句要点。第二句要点。第三句要点。第四句。"
    result = summarize_rules(text)
    assert result["summary"].startswith("第一句要点")
    assert len(result["key_points"]) == 3


def test_plan_rules_distributes_days():
    result = generate_plan_rules("复习", 60, ["Python", "MySQL"], 3)
    assert len(result["plan"]) == 3
    assert all(len(day["tasks"]) >= 1 for day in result["plan"])


def test_interview_turn_rules_finishes_at_8():
    result = interview_turn_rules("后端", "自我介绍", "一个很长的回答" * 5, 8)
    assert result["done"] is True
    assert result["scores"] is not None


def test_generate_questions_rules_variants():
    singles = generate_questions_rules(["Python"], "SINGLE", 2, 3)
    assert len(singles) == 2
    assert all(q["type"] == "SINGLE" for q in singles)


# ---------------------------------------------------------------------------
# 接口级：AI 场景 + DRAFT 审核流
# ---------------------------------------------------------------------------
@pytest.mark.asyncio
async def test_ai_job_explain_and_summary_endpoints(client):
    student = await login(client, "student")
    explain = await client.post(
        "/api/v1/ai/job-explain",
        headers=student,
        json={"job_title": "后端实习生", "required_skills": ["Python"], "match_score": 80.0, "matched_tags": ["Python"], "gap_tags": []},
    )
    assert explain.status_code == 200
    assert explain.json()["data"]["match_score"] == 80.0

    summary = await client.post("/api/v1/ai/summary", headers=student, json={"text": "要点一。要点二。要点三。"})
    assert summary.status_code == 200
    assert summary.json()["data"]["summary"]


@pytest.mark.asyncio
async def test_ai_plan_persists_study_plan(client):
    student = await login(client, "student")
    resp = await client.post(
        "/api/v1/ai/plan",
        headers=student,
        json={"goal": "期末复习", "daily_minutes": 60, "weak_kps": ["Python", "MySQL"], "days": 3},
    )
    assert resp.status_code == 200
    assert len(resp.json()["data"]["plan"]) == 3


@pytest.mark.asyncio
async def test_ai_interview_start_turn(client):
    student = await login(client, "student")
    start = await client.post("/api/v1/ai/interview/start", headers=student, json={"job_title": "后端实习生", "required_skills": ["Python"]})
    assert start.status_code == 200
    q = start.json()["data"]["question"]
    turn = await client.post("/api/v1/ai/interview/turn", headers=student, json={"job_title": "后端实习生", "question": q, "answer": "我是候选人，有丰富的项目经验，负责过后端接口开发并提升了性能。", "turn": 1})
    assert turn.status_code == 200
    assert turn.json()["data"]["feedback"]


@pytest.mark.asyncio
async def test_ai_question_draft_and_approve_flow(client):
    teacher = await login(client, "teacher")
    draft = await client.post(
        "/api/v1/ai/questions/draft",
        headers=teacher,
        json={"kp_names": ["Python 基础"], "type": "SINGLE", "count": 2, "difficulty": 3},
    )
    assert draft.status_code == 200
    qs = draft.json()["data"]["questions"]
    assert len(qs) == 2
    assert all(q["status"] == "DRAFT" for q in qs)
    qid = qs[0]["id"]

    # DRAFT 默认不进入 PUBLISHED 列表（通过 status 过滤验证）
    published = await client.get("/api/v1/questions", headers=teacher, params={"status": "PUBLISHED", "page_size": 100})
    assert all(q["id"] != qid for q in published.json()["data"]["items"])

    drafts = await client.get("/api/v1/questions", headers=teacher, params={"status": "DRAFT", "page_size": 100})
    assert any(q["id"] == qid for q in drafts.json()["data"]["items"])

    # 采纳 → PUBLISHED
    approve = await client.post("/api/v1/questions/drafts/approve", headers=teacher, json={"question_id": qid})
    assert approve.status_code == 200
    assert approve.json()["data"]["status"] == "PUBLISHED"

    # 丢弃另一道草稿
    other = qs[1]["id"]
    discard = await client.delete(f"/api/v1/questions/drafts/{other}", headers=teacher)
    assert discard.status_code == 200
