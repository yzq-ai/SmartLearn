import pytest
from httpx import ASGITransport, AsyncClient

from app.main import app
from app.services.rag import keyword_score, retrieve_top, tokenize


@pytest.fixture
async def client():
    async with app.router.lifespan_context(app):
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as http:
            yield http


async def login(client, username="student", password="1015401x"):
    resp = await client.post("/api/v1/auth/login", json={"username": username, "password": password})
    assert resp.status_code == 200
    return {"Authorization": f"Bearer {resp.json()['data']['access_token']}"}


def test_tokenize_and_keyword_score():
    tokens = tokenize("FastAPI 路由与接口测试")
    assert "fastapi" in tokens and "路由" in tokens
    assert keyword_score("FastAPI 的路由设计", tokenize("FastAPI 路由")) > 0
    assert keyword_score("无关内容", tokenize("FastAPI 路由")) == 0


def test_retrieve_top_ranks_and_filters():
    passages = [
        {"content": "FastAPI 路由使用装饰器定义", "source": "s1"},
        {"content": "排序算法的时间复杂度", "source": "s2"},
    ]
    results = retrieve_top(passages, "FastAPI 路由", top_k=4)
    assert results[0]["source"] == "s1"
    assert len(results) == 1  # s2 得分 0 被过滤


@pytest.mark.asyncio
async def test_course_qa_grounded_and_audited(client):
    student = await login(client, "student")
    resp = await client.post("/api/v1/ai/course-qa", headers=student, json={"course_id": 1, "query": "FastAPI 路由"})
    assert resp.status_code == 200
    body = resp.json()["data"]
    assert body["answer"]
    assert body["grounded"] is True
    assert any("FastAPI" in r["source"] for r in body["refs"])


@pytest.mark.asyncio
async def test_course_qa_unmatched_marks_generic(client):
    student = await login(client, "student")
    resp = await client.post("/api/v1/ai/course-qa", headers=student, json={"course_id": 1, "query": "完全无关的量子物理话题"})
    assert resp.status_code == 200
    body = resp.json()["data"]
    assert body["grounded"] is False
