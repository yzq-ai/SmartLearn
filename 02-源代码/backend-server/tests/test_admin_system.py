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


@pytest.mark.asyncio
async def test_sensitive_word_crud_and_audit(client):
    admin = await login(client, "admin", "1015401x")

    created = await client.post("/api/v1/admin/sensitive-words", headers=admin, json={"word": "测试违禁词", "level": 2})
    assert created.status_code == 200
    wid = created.json()["data"]["id"]

    # 重复报 409
    dup = await client.post("/api/v1/admin/sensitive-words", headers=admin, json={"word": "测试违禁词", "level": 2})
    assert dup.status_code == 409

    listed = await client.get("/api/v1/admin/sensitive-words", headers=admin)
    assert any(w["id"] == wid for w in listed.json()["data"])

    deleted = await client.delete(f"/api/v1/admin/sensitive-words/{wid}", headers=admin)
    assert deleted.status_code == 200

    # 审计日志已写入
    logs = await client.get("/api/v1/admin/audit-logs", headers=admin)
    actions = [log["action"] for log in logs.json()["data"]]
    assert "SENSITIVE_WORD_CREATE" in actions


@pytest.mark.asyncio
async def test_config_upsert_and_list(client):
    admin = await login(client, "admin", "1015401x")
    upsert = await client.put("/api/v1/admin/configs", headers=admin, json={"cfg_key": "ai_enabled", "cfg_value": "true", "remark": "AI 开关"})
    assert upsert.status_code == 200
    # 再次 upsert 覆盖
    upsert2 = await client.put("/api/v1/admin/configs", headers=admin, json={"cfg_key": "ai_enabled", "cfg_value": "false"})
    assert upsert2.json()["data"]["cfg_value"] == "false"
    listed = await client.get("/api/v1/admin/configs", headers=admin)
    assert any(c["cfg_key"] == "ai_enabled" for c in listed.json()["data"])


@pytest.mark.asyncio
async def test_skill_tag_crud(client):
    admin = await login(client, "admin", "1015401x")
    created = await client.post("/api/v1/admin/skill-tags", headers=admin, json={"name": "Kubernetes", "category": "框架"})
    assert created.status_code == 200
    tag_id = created.json()["data"]["id"]
    listed = await client.get("/api/v1/admin/skill-tags", headers=admin)
    assert any(t["id"] == tag_id for t in listed.json()["data"])
    deleted = await client.delete(f"/api/v1/admin/skill-tags/{tag_id}", headers=admin)
    assert deleted.status_code == 200


@pytest.mark.asyncio
async def test_user_management_flow(client):
    admin = await login(client, "admin", "1015401x")

    # 批量导入（含冲突与非法角色）——用户名带随机后缀保证测试可重复执行
    new_student = f"stu_{uuid.uuid4().hex[:8]}"
    import_resp = await client.post(
        "/api/v1/admin/users/import",
        headers=admin,
        json={"users": [
            {"username": new_student, "real_name": "张同学", "role": "STUDENT"},
            {"username": "teacher", "real_name": "冲突", "role": "TEACHER"},
            {"username": "bad_role", "real_name": "非法", "role": "SUPER"},
        ]},
    )
    assert import_resp.status_code == 200
    report = import_resp.json()["data"]
    assert report["success"] == 1
    assert report["failed"] == 2

    # 列表过滤角色
    students = await client.get("/api/v1/admin/users", headers=admin, params={"role": "STUDENT"})
    assert any(u["username"] == new_student for u in students.json()["data"])

    # 禁用
    target = next(u for u in students.json()["data"] if u["username"] == new_student)
    disabled = await client.put(f"/api/v1/admin/users/{target['id']}/status", headers=admin, json={"status": 0})
    assert disabled.json()["data"]["status"] == 0

    # 重置密码
    reset = await client.post(f"/api/v1/admin/users/{target['id']}/reset-password", headers=admin, json={"new_password": "NewPass123"})
    assert reset.status_code == 200

    # 禁用后登录被拒
    denied = await client.post("/api/v1/auth/login", json={"username": new_student, "password": "NewPass123"})
    assert denied.status_code == 403


@pytest.mark.asyncio
async def test_admin_endpoints_require_admin(client):
    teacher = await login(client, "teacher", "1015401x")
    for path in ("/api/v1/admin/sensitive-words", "/api/v1/admin/configs", "/api/v1/admin/skill-tags", "/api/v1/admin/users", "/api/v1/admin/audit-logs"):
        resp = await client.get(path, headers=teacher)
        assert resp.status_code == 403, path
