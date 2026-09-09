from unittest.mock import patch

import pytest
from httpx import ASGITransport, AsyncClient

from app.main import app


@pytest.fixture
async def client():
    async with app.router.lifespan_context(app):
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as http:
            yield http


async def login_admin(client):
    resp = await client.post("/api/v1/auth/login", json={"username": "admin", "password": "1015401x"})
    assert resp.status_code == 200
    return {"Authorization": f"Bearer {resp.json()['data']['access_token']}"}


@pytest.mark.asyncio
async def test_integrations_endpoint_lists_services(client):
    headers = await login_admin(client)
    resp = await client.get("/api/v1/admin/integrations", headers=headers)
    assert resp.status_code == 200
    data = resp.json()["data"]
    assert set(data.keys()) == {"obs", "push", "vector"}
    # 未配置时回退
    assert data["obs"]["configured"] is False
    assert data["vector"]["reachable"] is True  # memory 兜底可用


@pytest.mark.asyncio
async def test_integrations_requires_admin(client):
    resp = await client.post("/api/v1/auth/login", json={"username": "teacher", "password": "1015401x"})
    headers = {"Authorization": f"Bearer {resp.json()['data']['access_token']}"}
    assert (await client.get("/api/v1/admin/integrations", headers=headers)).status_code == 403


def test_obs_real_path_with_mock():
    """配置 OBS 后，head_bucket 成功 → reachable=True（真实 boto3 路径）。"""
    from app.core import config as cfg
    from app.services.obs import check_obs

    class FakeClient:
        def head_bucket(self, Bucket):  # noqa: N803
            return {"ResponseMetadata": {"HTTPStatusCode": 200}}

    with patch.object(cfg.settings, "obs_ak", "ak"), \
         patch.object(cfg.settings, "obs_sk", "sk"), \
         patch.object(cfg.settings, "obs_bucket", "bucket"), \
         patch("app.services.obs._client", return_value=FakeClient()):
        status = check_obs()
    assert status == {"configured": True, "reachable": True, "bucket": "bucket"}


def test_push_agc_real_path_with_mock():
    """配置 AGC 后，token + send 成功 → send_push 返回 True（真实 HTTP 路径）。"""
    from app.core import config as cfg
    from app.services.push_service import send_push

    with patch.object(cfg.settings, "push_backend", "agc"), \
         patch.object(cfg.settings, "agc_client_id", "cid"), \
         patch.object(cfg.settings, "agc_client_secret", "sec"), \
         patch.object(cfg.settings, "agc_app_id", "app"), \
         patch("app.services.push_service._agc_access_token", return_value="token"), \
         patch("app.services.push_service._agc_send", return_value=True):
        assert send_push([], "标题", "内容") is True
