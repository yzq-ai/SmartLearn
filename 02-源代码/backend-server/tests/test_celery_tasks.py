from datetime import timedelta

import pytest
from httpx import ASGITransport, AsyncClient

from app.main import app
from app.tasks.jobs import aggregate_daily_stats, auto_collect_exams, refresh_profile


@pytest.fixture
async def client():
    async with app.router.lifespan_context(app):
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as http:
            yield http


async def login(client, username="student", password="1015401x"):
    resp = await client.post("/api/v1/auth/login", json={"username": username, "password": password})
    assert resp.status_code == 200
    return {"Authorization": f"Bearer {resp.json()['data']['access_token']}"}


def test_aggregate_daily_stats_populates(client):
    result = aggregate_daily_stats.apply().get()
    assert result["courses"] >= 2


def test_auto_collect_exams_marks_expired(client):
    result = auto_collect_exams.apply().get()
    assert isinstance(result["collected"], int)


def test_refresh_profile_task_recomputes(client):
    result = refresh_profile.apply(args=[1]).get()
    assert isinstance(result["skill_scores"], dict)


@pytest.mark.asyncio
async def test_admin_can_trigger_tasks(client):
    admin = await login(client, "admin", "1015401x")
    resp = await client.post("/api/v1/admin/tasks/aggregate-stats", headers=admin)
    assert resp.status_code == 200
    assert resp.json()["data"]["task"] == "aggregate-stats"

    forbidden = await client.post("/api/v1/admin/tasks/aggregate-stats", headers=await login(client, "student"))
    assert forbidden.status_code == 403
