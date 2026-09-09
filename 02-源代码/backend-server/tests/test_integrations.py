import pytest
from httpx import ASGITransport, AsyncClient

from app.main import app
from app.services.obs import create_upload_token
from app.services.push_service import send_push
from app.services.vector_store import VectorStore


@pytest.fixture
async def client():
    async with app.router.lifespan_context(app):
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as http:
            yield http


async def login(client, username, password):
    resp = await client.post("/api/v1/auth/login", json={"username": username, "password": password})
    assert resp.status_code == 200
    return {"Authorization": f"Bearer {resp.json()['data']['access_token']}"}


def test_obs_upload_token_local_fallback():
    token = create_upload_token("doc/1.pdf")
    assert token["object_key"] == "doc/1.pdf"
    assert token["storage"] == "local"
    assert token["upload_url"] is None


def test_push_log_backend_returns_true():
    assert send_push([1, 2], "标题", "内容") is True


def test_vector_store_memory_search():
    store = VectorStore("memory")
    results = store.search(
        [{"content": "FastAPI 路由使用装饰器", "source": "s1"}, {"content": "排序算法", "source": "s2"}],
        "FastAPI 路由",
    )
    assert results[0]["source"] == "s1"


@pytest.mark.asyncio
async def test_resource_upload_token_and_create(client):
    teacher = await login(client, "teacher", "1015401x")
    token = await client.post("/api/v1/resources/upload-token", headers=teacher)
    assert token.status_code == 200
    assert token.json()["data"]["storage"] in ("local", "obs")

    created = await client.post("/api/v1/resources", headers=teacher, json={
        "file_name": "课件.pdf", "file_type": "pdf", "file_size": 1024, "oss_key": "doc/1.pdf",
    })
    assert created.status_code == 200
    assert created.json()["data"]["file_name"] == "课件.pdf"


@pytest.mark.asyncio
async def test_notification_publish_marks_push_sent(client):
    teacher = await login(client, "teacher", "1015401x")
    pub = await client.post("/api/v1/notifications", headers=teacher, json={"type": "SYSTEM", "title": "推送测试", "content": "内容", "target_role": "ALL"})
    assert pub.status_code == 200
    assert pub.json()["data"]["push_sent"] == 1
