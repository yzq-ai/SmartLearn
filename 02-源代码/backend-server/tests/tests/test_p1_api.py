import uuid

import pytest
from httpx import ASGITransport, AsyncClient

from app.main import app


@pytest.fixture
async def client():
    async with app.router.lifespan_context(app):
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as http:
            yield http


async def login(client, username, password):
    resp = await client.post("/api/v1/auth/login", json={"username": username, "password": password})
    assert resp.status_code == 200
    return {"Authorization": f"Bearer {resp.json()['data']['access_token']}"}


# ---------------------------------------------------------------------------
# 通知已读
# ---------------------------------------------------------------------------
@pytest.mark.asyncio
async def test_notification_read_flow(client):
    teacher = await login(client, "teacher", "1015401x")
    await client.post("/api/v1/notifications", headers=teacher, json={"type": "SYSTEM", "title": "已读测试", "content": "x", "target_role": "ALL"})

    student = await login(client, "student", "1015401x")
    # 未读计数 > 0
    unread = await client.get("/api/v1/notifications/unread-count", headers=student)
    assert unread.status_code == 200
    assert unread.json()["data"]["unread"] >= 1

    # 全部已读
    await client.put("/api/v1/notifications/read-all", headers=student, json={})
    unread2 = await client.get("/api/v1/notifications/unread-count", headers=student)
    assert unread2.json()["data"]["unread"] == 0

    # 单条已读（发布一条新的再读）
    await client.post("/api/v1/notifications", headers=teacher, json={"type": "SYSTEM", "title": "单条", "content": "y", "target_role": "ALL"})
    notifs = await client.get("/api/v1/notifications", headers=student)
    nid = notifs.json()["data"][0]["id"]
    mark = await client.put(f"/api/v1/notifications/{nid}/read", headers=student, json={})
    assert mark.status_code == 200


# ---------------------------------------------------------------------------
# 投递状态流转 + 简历快照
# ---------------------------------------------------------------------------
@pytest.mark.asyncio
async def test_application_status_flow_and_snapshot(client):
    student = await login(client, "student", "1015401x")
    # 先建简历，投递后应固化快照
    await client.post("/api/v1/resumes", headers=student, json={"title": "我的简历", "content": {"name": "张三", "skills": "Python"}})

    jobs = (await client.get("/api/v1/jobs/recommendations")).json()["data"]
    job_id = jobs[0]["id"]
    applied = await client.post(f"/api/v1/jobs/{job_id}/applications", headers=student, json={})
    assert applied.status_code == 200
    app_id = applied.json()["data"]["id"]

    teacher = await login(client, "teacher", "1015401x")
    # 学生无权改状态
    forbidden = await client.put(f"/api/v1/applications/{app_id}/status", headers=student, json={"status": "VIEWED"})
    assert forbidden.status_code == 403

    upd = await client.put(f"/api/v1/applications/{app_id}/status", headers=teacher, json={"status": "INTERVIEW"})
    assert upd.status_code == 200
    assert upd.json()["data"]["status"] == "INTERVIEW"

    # 非法状态
    bad = await client.put(f"/api/v1/applications/{app_id}/status", headers=teacher, json={"status": "FOO"})
    assert bad.status_code == 422


# ---------------------------------------------------------------------------
# 切屏监控 + 强制收卷
# ---------------------------------------------------------------------------
@pytest.mark.asyncio
async def test_monitor_and_force_submit(client):
    username = f"m_{uuid.uuid4().hex[:8]}"
    reg = await client.post("/api/v1/auth/register", json={"username": username, "password": "1015401x"})
    student = {"Authorization": f"Bearer {reg.json()['data']['access_token']}"}

    started = await client.post("/api/v1/exams/1/start", headers=student)
    assert started.status_code == 200
    record_id = started.json()["data"]["record_id"]

    # 切屏 1 次
    mon = await client.post(f"/api/v1/records/{record_id}/monitor", headers=student, json={})
    assert mon.status_code == 200
    assert mon.json()["data"]["switch_count"] == 1

    # 教师强制收卷
    teacher = await login(client, "teacher", "1015401x")
    forced = await client.post("/api/v1/exams/1/force-submit", headers=teacher, json={})
    assert forced.status_code == 200
    assert forced.json()["data"]["forced"] >= 1


# ---------------------------------------------------------------------------
# 规则抽题组卷
# ---------------------------------------------------------------------------
@pytest.mark.asyncio
async def test_random_paper(client):
    teacher = await login(client, "teacher", "1015401x")
    # 建两条 PUBLISHED 题
    for i in range(3):
        await client.post("/api/v1/questions", headers=teacher, json={
            "type": "SINGLE", "content": f"抽题测试{i}", "answer": "A", "options": ["A", "B"], "difficulty": 2, "score": 5, "course_id": 1,
        })
    paper = await client.post("/api/v1/papers/random", headers=teacher, json={"course_id": 1, "title": "抽题卷", "count": 2})
    assert paper.status_code == 200
    assert len(paper.json()["data"]["questions"]) == 2


# ---------------------------------------------------------------------------
# AI feedback + SSE
# ---------------------------------------------------------------------------
@pytest.mark.asyncio
async def test_ai_feedback_and_stream(client):
    student = await login(client, "student", "1015401x")
    qa = await client.post("/api/v1/ai/course-qa", headers=student, json={"course_id": 1, "query": "FastAPI 路由"})
    assert qa.status_code == 200
    log_id = qa.json()["data"]["log_id"]

    fb = await client.post("/api/v1/ai/feedback", headers=student, json={"log_id": log_id, "feedback": 1})
    assert fb.status_code == 200
    assert fb.json()["data"]["feedback"] == 1

    stream = await client.post("/api/v1/ai/chat/stream", headers=student, json={"course_id": 1, "query": "FastAPI 路由"})
    assert stream.status_code == 200
    assert "data:" in stream.text


# ---------------------------------------------------------------------------
# 就业匹配真实化：画像 + 技能权重 + gap 补强课程
# ---------------------------------------------------------------------------
@pytest.mark.asyncio
async def test_profile_based_matching_and_gap_courses(client):
    # 未登录用演示画像，仍返回匹配分解
    recs = await client.get("/api/v1/jobs/recommendations")
    assert recs.status_code == 200
    first = recs.json()["data"][0]
    assert "match_score" in first and "gap_courses" in first

    # 登录学生（有画像），岗位详情应返回 gap 补强课程
    student = await login(client, "student", "1015401x")
    job_id = recs.json()["data"][0]["id"]
    detail = await client.get(f"/api/v1/jobs/{job_id}", headers=student)
    assert detail.status_code == 200
    body = detail.json()["data"]
    assert "gap_courses" in body
    assert isinstance(body["gap_courses"], list)
