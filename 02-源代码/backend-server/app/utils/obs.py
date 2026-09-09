"""对象存储工具（boto3 S3 兼容预签名直传）。"""
from __future__ import annotations
import logging
from app.core.config import settings

logger = logging.getLogger(__name__)

def is_configured() -> bool:
    return bool(settings.obs_ak and settings.obs_sk and settings.obs_bucket and settings.obs_endpoint)

def generate_presigned_url(key: str, expires: int = 7200, method: str = "get") -> str | None:
    if not is_configured():
        return None
    try:
        import boto3
        client = boto3.client("s3", aws_access_key_id=settings.obs_ak, aws_secret_access_key=settings.obs_sk, endpoint_url=settings.obs_endpoint)
        if method == "put":
            return client.generate_presigned_url("put_object", Params={"Bucket": settings.obs_bucket, "Key": key}, ExpiresIn=expires)
        return client.generate_presigned_url("get_object", Params={"Bucket": settings.obs_bucket, "Key": key}, ExpiresIn=expires)
    except Exception as e:
        logger.warning("OBS presign failed: %s", e)
        return None
