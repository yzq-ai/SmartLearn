"""OBS 对象存储（S3 兼容协议）。

未配置 OBS 时回退到本地标记（``storage=local``）；配置后走 boto3 真实预签名。
``check_obs`` 用于集成状态探测，判断配置是否完整、连接是否可达。
"""
from __future__ import annotations

import uuid

from app.core.config import settings


def _configured() -> bool:
    return bool(settings.obs_bucket and settings.obs_ak and settings.obs_sk)


def _client():
    import boto3
    from botocore.client import Config

    return boto3.client(
        "s3",
        aws_access_key_id=settings.obs_ak,
        aws_secret_access_key=settings.obs_sk,
        endpoint_url=settings.obs_endpoint or None,
        config=Config(signature_version="s3v4"),
    )


def create_upload_token(object_key: str | None = None) -> dict:
    key = object_key or f"resources/{uuid.uuid4().hex}.bin"
    if not _configured():
        return {"object_key": key, "storage": "local", "upload_url": None}
    url = _client().generate_presigned_url(
        "put_object",
        Params={"Bucket": settings.obs_bucket, "Key": key},
        ExpiresIn=7200,
    )
    return {"object_key": key, "storage": "obs", "upload_url": url}


def check_obs() -> dict:
    """返回 OBS 配置与连通性状态（不抛异常）。"""
    if not _configured():
        return {"configured": False, "reachable": False, "reason": "未配置 OBS_AK/OBS_SK/OBS_BUCKET"}
    try:
        _client().head_bucket(Bucket=settings.obs_bucket)
        return {"configured": True, "reachable": True, "bucket": settings.obs_bucket}
    except Exception as exc:  # noqa: BLE001 - 探测失败不致命
        return {"configured": True, "reachable": False, "reason": type(exc).__name__}
