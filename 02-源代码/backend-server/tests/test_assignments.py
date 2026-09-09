import pytest
from httpx import ASGITransport, AsyncClient

from app.main import app


@pytest.fixture
async def client():
    async with app.router.lifespan_context(app):
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as http:
            yield http


async def login(client, username, password="1015401x"):
    resp = await client.post("/api/v1/auth/login", json={"username": username, "password": password})
    assert resp.status_code == 200
    return {"Authorization": f"Bearer {resp.json()['data']['access_token']}"}


@pytest.mark.asyncio
async def test_assignment_full_flow(client):
    teacher = await login(client, "teacher")
    student = await login(client, "student")

    # 教师发布作业
    created = await client.post(
        "/api/v1/assignments",
        headers=teacher,
        json={"course_id": 1, "title": "单元测试作业", "max_score": 100, "deadline": "2099-01-01T00:00:00"},
    )
    assert created.status_code == 200
    assignment_id = created.json()["data"]["id"]

    # 学生三态列表：初始未提交
    listed = await client.get("/api/v1/assignments", headers=student, params={"course_id": 1})
    assert any(a["id"] == assignment_id and a["my_submission"] is None for a in listed.json()["data"])

    # 学生提交
    submit = await client.post(
        f"/api/v1/assignments/{assignment_id}/submit",
        headers=student,
        json={"content": "已实现接口，见仓库 README。"},
    )
    assert submit.status_code == 200
    assert submit.json()["data"]["status"] == "SUBMITTED"

    # 重复提交覆盖（未批改前允许）
    submit2 = await client.post(
        f"/api/v1/assignments/{assignment_id}/submit",
        headers=student,
        json={"content": "补充了单元测试与参数校验。"},
    )
    assert submit2.json()["data"]["version"] == 2

    # 教师查看提交列表
    submissions = await client.get(f"/api/v1/assignments/{assignment_id}/submissions", headers=teacher)
    assert submissions.status_code == 200
    assert len(submissions.json()["data"]) == 1
    sub_id = submissions.json()["data"][0]["id"]

    # 教师批改
    grade = await client.post(
        f"/api/v1/submissions/{sub_id}/grade",
        headers=teacher,
        json={"score": 90, "feedback": "完成良好，注意补充异常处理。"},
    )
    assert grade.status_code == 200
    assert grade.json()["data"]["status"] == "GRADED"

    # 批改后学生列表看到成绩
    listed_after = await client.get("/api/v1/assignments", headers=student, params={"course_id": 1})
    row = next(a for a in listed_after.json()["data"] if a["id"] == assignment_id)
    assert row["my_submission"]["score"] == 90
    assert row["my_submission"]["status"] == "GRADED"


@pytest.mark.asyncio
async def test_assignment_grade_lock_and_redo(client):
    teacher = await login(client, "teacher")
    student = await login(client, "student")

    created = (await client.post("/api/v1/assignments", headers=teacher, json={"course_id": 1, "title": "锁定作业", "max_score": 100, "deadline": "2099-01-01T00:00:00"})).json()["data"]
    sub = (await client.post(f"/api/v1/assignments/{created['id']}/submit", headers=student, json={"content": "初版"})).json()["data"]
    sub_id = sub["id"]

    await client.post(f"/api/v1/submissions/{sub_id}/grade", headers=teacher, json={"score": 60, "feedback": "需改进"})

    # 批改后锁定，重复提交 409
    locked = await client.post(f"/api/v1/assignments/{created['id']}/submit", headers=student, json={"content": "改版"})
    assert locked.status_code == 409

    # 退回重做后允许再次提交
    await client.post(f"/api/v1/submissions/{sub_id}/grade", headers=teacher, json={"score": 60, "feedback": "请修改", "return_for_redo": True})
    redo = await client.post(f"/api/v1/assignments/{created['id']}/submit", headers=student, json={"content": "改版已提交"})
    assert redo.status_code == 200


@pytest.mark.asyncio
async def test_assignment_requires_teacher_to_create(client):
    student = await login(client, "student")
    forbidden = await client.post("/api/v1/assignments", headers=student, json={"course_id": 1, "title": "x", "max_score": 100, "deadline": "2099-01-01T00:00:00"})
    assert forbidden.status_code == 403
