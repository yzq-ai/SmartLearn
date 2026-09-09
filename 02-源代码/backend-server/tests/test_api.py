import uuid

import pytest
from httpx import ASGITransport, AsyncClient

from app.database import init_db
from app.main import app


@pytest.fixture
async def client():
    await init_db()
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as http_client:
        yield http_client


async def auth_headers(client):
    username = f"exam_{uuid.uuid4().hex[:10]}"
    response = await client.post(
        "/api/v1/auth/register",
        json={"username": username, "password": "1015401x"},
    )
    assert response.status_code == 200
    return {"Authorization": f"Bearer {response.json()['data']['access_token']}"}


@pytest.mark.asyncio
async def test_health(client):
    response = await client.get("/health")
    assert response.status_code == 200 and response.json()["status"] == "ok"


@pytest.mark.asyncio
async def test_login_and_courses(client):
    response = await client.post("/api/v1/auth/login", json={"username": "student", "password": "1015401x"})
    assert response.status_code == 200
    body = response.json()
    assert body["code"] == 0 and body["data"]["user"]["role"] == "STUDENT"

    response = await client.get("/api/v1/courses")
    assert response.status_code == 200
    assert len(response.json()["data"]) >= 2


@pytest.mark.asyncio
async def test_exam_requires_login_and_start(client):
    response = await client.post("/api/v1/exams/1/start")
    assert response.status_code == 401
    assert response.json()["code"] == 1001

    headers = await auth_headers(client)
    response = await client.post(
        "/api/v1/exams/1/submit",
        headers=headers,
        json={"answers": [{"question_id": 1, "answer": "A"}]},
    )
    assert response.status_code == 409
    assert "开始" in response.json()["message"]


@pytest.mark.asyncio
async def test_exam_persistent_lifecycle_and_duplicate_submit(client):
    headers = await auth_headers(client)

    detail = (await client.get("/api/v1/exams/1", headers=headers)).json()["data"]
    q_ids = [q["id"] for q in detail["questions"]]

    started = await client.post("/api/v1/exams/1/start", headers=headers)
    assert started.status_code == 200
    assert started.json()["data"]["status"] == "IN_PROGRESS"
    record_id = started.json()["data"]["record_id"]

    # Start is idempotent while the attempt remains open.
    started_again = await client.post("/api/v1/exams/1/start", headers=headers)
    assert started_again.status_code == 200
    assert started_again.json()["data"]["record_id"] == record_id

    saved = await client.put(
        "/api/v1/exams/1/answers",
        headers=headers,
        json={"answers": [{"question_id": q_ids[0], "answer": "A"}]},
    )
    assert saved.status_code == 200
    assert saved.json()["data"]["answers"] == [{"question_id": q_ids[0], "answer": "A"}]

    state = await client.get("/api/v1/exams/1/state", headers=headers)
    assert state.status_code == 200
    assert state.json()["data"]["record_id"] == record_id
    assert state.json()["data"]["answers"][0]["answer"] == "A"

    submitted = await client.post(
        "/api/v1/exams/1/submit",
        headers=headers,
        json={"answers": [{"question_id": q_ids[1], "answer": "true"}]},
    )
    assert submitted.status_code == 200
    assert submitted.json()["data"]["score"] == 100

    final_state = await client.get("/api/v1/exams/1/state", headers=headers)
    assert final_state.json()["data"]["status"] == "SUBMITTED"
    assert final_state.json()["data"]["score"] == 100

    duplicate = await client.post(
        "/api/v1/exams/1/submit",
        headers=headers,
        json={"answers": []},
    )
    assert duplicate.status_code == 409
    assert "重复" in duplicate.json()["message"]


@pytest.mark.asyncio
async def test_exam_rejects_foreign_question(client):
    headers = await auth_headers(client)
    await client.post("/api/v1/exams/1/start", headers=headers)
    response = await client.put(
        "/api/v1/exams/1/answers",
        headers=headers,
        json={"answers": [{"question_id": 999999, "answer": "A"}]},
    )
    assert response.status_code == 422


@pytest.mark.asyncio
async def test_compatible_exam_get_does_not_leak_answers(client):
    response = await client.get("/api/v1/exams/1")
    assert response.status_code == 200
    assert response.json()["data"]["questions"]
    assert all("answer" not in question for question in response.json()["data"]["questions"])


@pytest.mark.asyncio
async def test_job_recommendations(client):
    response = await client.get("/api/v1/jobs/recommendations")
    assert response.status_code == 200
    assert response.json()["data"][0]["match_score"] > 0
