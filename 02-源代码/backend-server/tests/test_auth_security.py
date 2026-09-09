import uuid

import pytest
from httpx import ASGITransport, AsyncClient
from sqlalchemy import select

from app.main import app
from app.models import SysLoginLog


@pytest.fixture
async def client():
    async with app.router.lifespan_context(app):
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as http:
            yield http


async def login(client, username, password="1015401x"):
    resp = await client.post("/api/v1/auth/login", json={"username": username, "password": password})
    assert resp.status_code == 200
    return resp.json()["data"]


@pytest.mark.asyncio
async def test_login_returns_refresh_and_pwd_changed(client):
    data = await login(client, "student")
    assert data["access_token"]
    assert data["refresh_token"]
    assert "pwd_changed" in data


@pytest.mark.asyncio
async def test_refresh_token_flow(client):
    data = await login(client, "student")
    resp = await client.post("/api/v1/auth/refresh", json={"refresh_token": data["refresh_token"]})
    assert resp.status_code == 200
    assert resp.json()["data"]["access_token"]

    # access token 不能当 refresh 用（type 校验）
    bad = await client.post("/api/v1/auth/refresh", json={"refresh_token": data["access_token"]})
    assert bad.status_code == 401


@pytest.mark.asyncio
async def test_logout_blacklists_access_token(client):
    data = await login(client, "student")
    headers = {"Authorization": f"Bearer {data['access_token']}"}
    assert (await client.get("/api/v1/profile/me", headers=headers)).status_code == 200

    out = await client.post("/api/v1/auth/logout", headers=headers, json={})
    assert out.status_code == 200

    # 登出后原 access token 失效
    assert (await client.get("/api/v1/profile/me", headers=headers)).status_code == 401


@pytest.mark.asyncio
async def test_login_lockout_after_5_failures(client):
    username = f"lock_{uuid.uuid4().hex[:8]}"
    for _ in range(5):
        resp = await client.post("/api/v1/auth/login", json={"username": username, "password": "wrong"})
        assert resp.status_code == 401
    resp = await client.post("/api/v1/auth/login", json={"username": username, "password": "wrong"})
    assert resp.status_code == 423


@pytest.mark.asyncio
async def test_change_password_and_login_log(client):
    username = f"pwd_{uuid.uuid4().hex[:8]}"
    data = await login(client, "student")
    headers = {"Authorization": f"Bearer {data['access_token']}"}

    # 用独立账号，避免污染共享的 student 密码
    reg = await client.post("/api/v1/auth/register", json={"username": username, "password": "1015401x"})
    assert reg.status_code == 200
    reg_headers = {"Authorization": f"Bearer {reg.json()['data']['access_token']}"}

    # 原密码错误
    wrong = await client.put("/api/v1/auth/password", headers=reg_headers, json={"old_password": "bad", "new_password": "NewPass123"})
    assert wrong.status_code == 400

    # 改密成功
    ok = await client.put("/api/v1/auth/password", headers=reg_headers, json={"old_password": "1015401x", "new_password": "NewPass123"})
    assert ok.status_code == 200

    # 新密码可登录且 pwd_changed=1
    new = await login(client, username, "NewPass123")
    assert new["pwd_changed"] == 1

    # 登录日志已写入
    from app.database import SessionLocal
    async with SessionLocal() as db:
        rows = (await db.execute(select(SysLoginLog).where(SysLoginLog.user_id == new["user"]["id"]))).scalars().all()
        assert len(rows) >= 1


@pytest.mark.asyncio
async def test_deactivate_and_cancel(client):
    data = await login(client, "student")
    headers = {"Authorization": f"Bearer {data['access_token']}"}

    deact = await client.post("/api/v1/users/me/deactivate", headers=headers, json={})
    assert deact.status_code == 200
    assert deact.json()["data"]["deleted_at"] is not None

    cancel = await client.post("/api/v1/users/me/deactivate/cancel", headers=headers, json={})
    assert cancel.status_code == 200


def test_full_rbac_permission_map():
    from app.core.deps import _ROLE_PERMS
    assert "exam:take" in _ROLE_PERMS["STUDENT"]
    assert "course:create" in _ROLE_PERMS["TEACHER"]
    assert "job:review" in _ROLE_PERMS["TEACHER"]
    assert "*" in _ROLE_PERMS["ADMIN"]
