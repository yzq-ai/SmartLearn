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


@pytest.mark.asyncio
async def test_create_exam_and_monitor(client):
    teacher = await login(client, "teacher", "1015401x")
    # 题库里已有 PUBLISHED 题（考试2 的题目属于 exam2，不 PUBLISHED 过滤场景需手工建题）
    q = await client.post("/api/v1/questions", headers=teacher, json={
        "type": "SINGLE", "content": "监控测试题？", "answer": "A", "options": ["A", "B"], "difficulty": 2, "score": 10,
    })
    qid = q.json()["data"]["id"]

    created = await client.post("/api/v1/exams", headers=teacher, json={
        "course_id": 1, "title": "监控测试考试", "duration_min": 30, "pass_score": 6, "question_ids": [qid],
    })
    assert created.status_code == 200
    exam_id = created.json()["data"]["id"]
    assert created.json()["data"]["total_score"] == 10

    monitor = await client.get(f"/api/v1/exams/{exam_id}/monitor", headers=teacher)
    assert monitor.status_code == 200
    assert isinstance(monitor.json()["data"], list)


@pytest.mark.asyncio
async def test_subjective_grading_flow(client):
    student = await login(client, "student", "1015401x")
    teacher = await login(client, "teacher", "1015401x")

    # 考试2 含 SHORT 题，学生交卷后状态 GRADING
    exam = (await client.get("/api/v1/exams/2")).json()["data"]
    answers = []
    for q in exam["questions"]:
        if q["type"] == "SHORT":
            answers.append({"question_id": q["id"], "answer": "资源抽象、无状态、统一接口"})
        elif q["type"] == "MULTI":
            answers.append({"question_id": q["id"], "answer": "GET,POST"})
        elif q["type"] == "BLANK":
            answers.append({"question_id": q["id"], "answer": "uvicorn"})
        else:
            answers.append({"question_id": q["id"], "answer": "A"})

    await client.post("/api/v1/exams/2/start", headers=student)
    submitted = await client.post("/api/v1/exams/2/submit", headers=student, json={"answers": answers})
    # 可能因已交卷返回 409，否则应成功
    assert submitted.status_code in (200, 409)

    monitor = await client.get("/api/v1/exams/2/monitor", headers=teacher)
    records = [r for r in monitor.json()["data"] if r["status"] == "GRADING"]
    if records:
        record_id = records[0]["record_id"]
        answer_list = await client.get(f"/api/v1/records/{record_id}/answers", headers=teacher)
        assert answer_list.status_code == 200
        short = [a for a in answer_list.json()["data"] if a["type"] == "SHORT"]
        if short:
            grade = await client.post(f"/api/v1/answers/{short[0]['answer_id']}/grade", headers=teacher, json={"score": 15, "comment": "不错"})
            assert grade.status_code == 200
            assert grade.json()["data"]["score"] == 15


@pytest.mark.asyncio
async def test_notification_publish_and_receive(client):
    teacher = await login(client, "teacher", "1015401x")
    pub = await client.post("/api/v1/notifications", headers=teacher, json={"type": "SYSTEM", "title": "开考提醒", "content": "明天考试", "target_role": "ALL"})
    assert pub.status_code == 200

    student = await login(client, "student", "1015401x")
    notifs = await client.get("/api/v1/notifications", headers=student)
    assert any(n["title"] == "开考提醒" for n in notifs.json()["data"])


@pytest.mark.asyncio
async def test_resume_crud(client):
    student = await login(client, "student", "1015401x")
    created = await client.post("/api/v1/resumes", headers=student, json={"title": "我的简历", "content": {"name": "张三", "skills": "Python"}})
    assert created.status_code == 200
    listed = await client.get("/api/v1/resumes", headers=student)
    assert len(listed.json()["data"]) >= 1


@pytest.mark.asyncio
async def test_company_list_and_job_detail(client):
    admin = await login(client, "admin", "1015401x")
    companies = await client.get("/api/v1/companies", headers=admin)
    assert companies.status_code == 200
    assert len(companies.json()["data"]) >= 1

    student = await login(client, "student", "1015401x")
    job_detail = await client.get("/api/v1/jobs/1", headers=student)
    assert job_detail.status_code == 200
    assert "matched_tags" in job_detail.json()["data"]


@pytest.mark.asyncio
async def test_question_detail_and_course_update(client):
    teacher = await login(client, "teacher", "1015401x")
    q = await client.get("/api/v1/questions/1", headers=teacher)
    assert q.status_code == 200

    updated = await client.put("/api/v1/courses/1", headers=teacher, json={"title": "Python 后端开发（改）", "description": "更新"})
    assert updated.status_code == 200
    assert updated.json()["data"]["title"] == "Python 后端开发（改）"


@pytest.mark.asyncio
async def test_discussion_delete_requires_teacher(client):
    student = await login(client, "student", "1015401x")
    teacher = await login(client, "teacher", "1015401x")
    post = await client.post("/api/v1/discussions", headers=student, json={"course_id": 1, "content": "待删除测试帖"})
    pid = post.json()["data"]["id"]

    forbidden = await client.delete(f"/api/v1/discussions/{pid}", headers=student)
    assert forbidden.status_code == 403

    deleted = await client.delete(f"/api/v1/discussions/{pid}", headers=teacher)
    assert deleted.status_code == 200
