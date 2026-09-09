import uuid

import pytest
from httpx import ASGITransport, AsyncClient

from app.main import app
from app.services.sensitive import scan_sensitive


@pytest.fixture
async def client():
    async with app.router.lifespan_context(app):
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as http:
            yield http


async def login(client, username="student", password="1015401x"):
    resp = await client.post("/api/v1/auth/login", json={"username": username, "password": password})
    assert resp.status_code == 200
    return {"Authorization": f"Bearer {resp.json()['data']['access_token']}"}


def test_scan_sensitive_matches_case_insensitive():
    assert "刷单" in scan_sensitive("这里提供刷单服务", ["刷单", "代考"])
    assert scan_sensitive("正常岗位描述", ["刷单", "代考"]) == []


@pytest.mark.asyncio
async def test_job_requires_review_before_public(client):
    teacher = await login(client, "teacher")
    created = await client.post(
        "/api/v1/jobs",
        headers=teacher,
        json={"title": "测试岗", "company": "测试企业", "description": "正常描述", "required_skills": ["Python"]},
    )
    assert created.status_code == 200
    assert created.json()["data"]["review_status"] == 0
    job_id = created.json()["data"]["id"]

    # 未审核前不出现在推荐列表
    jobs = await client.get("/api/v1/jobs/recommendations")
    assert all(j["id"] != job_id for j in jobs.json()["data"])

    # 管理员审核通过后出现在推荐列表
    admin = await login(client, "admin", "1015401x")
    approve = await client.post(
        "/api/v1/admin/reviews",
        headers=admin,
        json={"target_type": "JOB", "target_id": job_id, "action": "APPROVE"},
    )
    assert approve.status_code == 200
    jobs = await client.get("/api/v1/jobs/recommendations")
    assert any(j["id"] == job_id for j in jobs.json()["data"])


@pytest.mark.asyncio
async def test_review_reject_requires_reason(client):
    admin = await login(client, "admin", "1015401x")
    resp = await client.post(
        "/api/v1/admin/reviews",
        headers=admin,
        json={"target_type": "JOB", "target_id": 999999, "action": "REJECT", "reason": ""},
    )
    assert resp.status_code == 422


@pytest.mark.asyncio
async def test_question_bank_crud_requires_teacher(client):
    student = await login(client, "student")
    forbidden = await client.get("/api/v1/questions", headers=student)
    assert forbidden.status_code == 403

    teacher = await login(client, "teacher")
    created = await client.post(
        "/api/v1/questions",
        headers=teacher,
        json={"type": "SINGLE", "content": "测试题？", "answer": "A", "options": ["A", "B"], "difficulty": 2, "score": 5},
    )
    assert created.status_code == 200
    qid = created.json()["data"]["id"]

    updated = await client.put(
        f"/api/v1/questions/{qid}",
        headers=teacher,
        json={"type": "SINGLE", "content": "测试题（改）？", "answer": "B", "options": ["A", "B"], "difficulty": 3, "score": 10},
    )
    assert updated.status_code == 200
    assert updated.json()["data"]["content"] == "测试题（改）？"

    listed = await client.get("/api/v1/questions", headers=teacher, params={"page_size": 100})
    assert any(q["id"] == qid for q in listed.json()["data"]["items"])


@pytest.mark.asyncio
async def test_stats_and_dashboard_require_roles(client):
    teacher = await login(client, "teacher")
    stats = await client.get("/api/v1/stats/learning", headers=teacher)
    assert stats.status_code == 200
    assert "courses" in stats.json()["data"]

    admin = await login(client, "admin", "1015401x")
    dash = await client.get("/api/v1/admin/stats/dashboard", headers=admin)
    assert dash.status_code == 200
    assert dash.json()["data"]["users"] >= 3
    assert dash.json()["data"]["pending_jobs"] >= 1

    # 教师无权访问管理大屏
    forbidden = await client.get("/api/v1/admin/stats/dashboard", headers=teacher)
    assert forbidden.status_code == 403
