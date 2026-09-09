import uuid

import pytest
from httpx import ASGITransport, AsyncClient

from app.main import app


@pytest.fixture
async def client():
    async with app.router.lifespan_context(app):
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as http:
            yield http


async def register_student(client):
    username = f"s_{uuid.uuid4().hex[:8]}"
    resp = await client.post("/api/v1/auth/register", json={"username": username, "password": "1015401x"})
    assert resp.status_code == 200
    token = resp.json()["data"]["access_token"]
    return {"Authorization": f"Bearer {token}"}, username


@pytest.mark.asyncio
async def test_wrong_answer_collects_and_profile_refreshes(client):
    headers, _username = await register_student(client)

    # 找到考试 1（含成绩的 FastAPI 测验）及其题目
    detail = (await client.get("/api/v1/exams/1", headers=headers)).json()["data"]
    q_ids = [q["id"] for q in detail["questions"]]
    assert len(q_ids) == 2

    await client.post("/api/v1/exams/1/start", headers=headers)
    submitted = await client.post(
        "/api/v1/exams/1/submit",
        headers=headers,
        json={"answers": [{"question_id": q_ids[0], "answer": "B"}, {"question_id": q_ids[1], "answer": "false"}]},
    )
    assert submitted.status_code == 200
    assert submitted.json()["data"]["score"] == 0

    wrong = await client.get("/api/v1/wrong-questions", headers=headers)
    assert wrong.status_code == 200
    rows = wrong.json()["data"]
    assert len(rows) == 2
    assert {r["question_id"] for r in rows} == set(q_ids)
    assert all(r["wrong_count"] == 1 for r in rows)

    profile = await client.get("/api/v1/profile/me", headers=headers)
    assert profile.status_code == 200
    scores = profile.json()["data"]["skill_scores"]
    assert any(v == 0.0 for v in scores.values())


@pytest.mark.asyncio
async def test_mark_wrong_mastered(client):
    headers, _username = await register_student(client)
    detail = (await client.get("/api/v1/exams/1", headers=headers)).json()["data"]
    q_ids = [q["id"] for q in detail["questions"]]
    await client.post("/api/v1/exams/1/start", headers=headers)
    await client.post(
        "/api/v1/exams/1/submit",
        headers=headers,
        json={"answers": [{"question_id": q_ids[0], "answer": "B"}, {"question_id": q_ids[1], "answer": "false"}]},
    )
    wrong = (await client.get("/api/v1/wrong-questions", headers=headers)).json()["data"]
    wid = wrong[0]["id"]
    resp = await client.put(f"/api/v1/wrong-questions/{wid}/mastered", headers=headers)
    assert resp.status_code == 200
    assert resp.json()["data"]["is_mastered"] == 1


@pytest.mark.asyncio
async def test_profile_requires_student_role(client):
    # teacher 不能访问学生画像。
    login = await client.post("/api/v1/auth/login", json={"username": "teacher", "password": "1015401x"})
    headers = {"Authorization": f"Bearer {login.json()['data']['access_token']}"}
    resp = await client.get("/api/v1/profile/me", headers=headers)
    assert resp.status_code == 403
