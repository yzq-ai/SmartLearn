import pytest
from httpx import ASGITransport, AsyncClient

from app.main import app


@pytest.fixture
async def client():
    async with app.router.lifespan_context(app):
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as http:
            yield http


async def login(client, username="student", password="1015401x"):
    response = await client.post("/api/v1/auth/login", json={"username": username, "password": password})
    assert response.status_code == 200
    return {"Authorization": f"Bearer {response.json()['data']['access_token']}"}


@pytest.mark.asyncio
async def test_course_chapter_and_section_details(client):
    course = await client.get("/api/v1/courses/1")
    assert course.status_code == 200
    chapter = course.json()["data"]["chapters"][0]
    assert chapter["description"]
    assert chapter["sections"]

    section = chapter["sections"][0]
    response = await client.get(
        f"/api/v1/courses/1/chapters/{chapter['id']}/sections/{section['id']}"
    )
    assert response.status_code == 200
    assert response.json()["data"]["content"]


@pytest.mark.asyncio
async def test_progress_update_is_idempotent_and_scoped_to_login_user(client):
    headers = await login(client)
    course = (await client.get("/api/v1/courses/1")).json()["data"]
    chapter = course["chapters"][0]
    section = chapter["sections"][0]
    payload = {"percent": 35, "chapter_id": chapter["id"], "section_id": section["id"]}

    first = await client.put("/api/v1/progress/1", json=payload, headers=headers)
    second = await client.put("/api/v1/progress/1", json=payload, headers=headers)
    assert first.status_code == second.status_code == 200
    assert first.json()["data"]["id"] == second.json()["data"]["id"]

    progress = await client.get("/api/v1/progress", headers=headers)
    assert len([row for row in progress.json()["data"] if row["course_id"] == 1]) == 1
    assert (await client.get("/api/v1/progress")).status_code == 401


@pytest.mark.asyncio
async def test_job_application_and_favorite_are_idempotent_and_rbac_protected(client):
    student_headers = await login(client)
    recommendations = await client.get("/api/v1/jobs/recommendations")
    assert recommendations.status_code == 200
    job_id = recommendations.json()["data"][0]["id"]

    first = await client.post(f"/api/v1/jobs/{job_id}/applications", headers=student_headers)
    second = await client.post(f"/api/v1/jobs/{job_id}/applications", headers=student_headers)
    assert first.status_code == second.status_code == 200
    assert first.json()["data"]["id"] == second.json()["data"]["id"]

    assert (await client.put(f"/api/v1/jobs/{job_id}/favorite", headers=student_headers)).json()["data"]["favorited"]
    assert (await client.put(f"/api/v1/jobs/{job_id}/favorite", headers=student_headers)).json()["data"]["favorited"]
    favorites = await client.get("/api/v1/jobs/favorites", headers=student_headers)
    assert [job["id"] for job in favorites.json()["data"]].count(job_id) == 1

    teacher_headers = await login(client, "teacher")
    forbidden = await client.post(f"/api/v1/jobs/{job_id}/applications", headers=teacher_headers)
    assert forbidden.status_code == 403
