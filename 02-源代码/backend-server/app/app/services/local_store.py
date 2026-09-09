"""本地文件存储服务（无 OBS 时的真实落盘方案）。

市场交付要求：未配置对象存储时，资源文件必须真实写入服务器磁盘，
且学生端可下载回放，而不是只登记元数据。

- 存储目录：LOCAL_STORAGE_DIR（默认 ./storage），按日期分子目录。
- 上传：FastAPI multipart 直传（≤50MB），流式写盘防内存峰值。
- 下载：GET /resources/{id}/download 以 FileResponse 回源文件。
- 安全校验：扩展名白名单 + 大小上限 + 文件名净化（防路径穿越）。
"""
from __future__ import annotations

import re
import shutil
import uuid
from datetime import datetime
from pathlib import Path

from fastapi import HTTPException, UploadFile

from app.core.config import settings

ALLOWED_EXTS = {
    # 视频
    "mp4", "mov", "avi", "mkv", "webm",
    # 文档
    "pdf", "doc", "docx", "ppt", "pptx", "xls", "xlsx", "txt", "md",
    # 图片
    "png", "jpg", "jpeg", "webp",
}
MAX_UPLOAD_BYTES = 50 * 1024 * 1024  # 50MB

_STORAGE_DIR: Path | None = None


def storage_dir() -> Path:
    """返回存储根目录（懒创建）。"""
    global _STORAGE_DIR
    if _STORAGE_DIR is None:
        root = Path(settings.local_storage_dir).resolve()
        root.mkdir(parents=True, exist_ok=True)
        _STORAGE_DIR = root
    return _STORAGE_DIR


def sanitize_filename(name: str) -> str:
    """净化文件名：去路径、去控制字符、限长，保留中文与常见字符。"""
    base = Path(name).name
    base = re.sub(r"[\x00-\x1f<>:\"/\\|?*]", "_", base)
    base = base.strip(". ")
    if not base:
        base = "file"
    if len(base) > 120:
        stem = base[:100]
        ext = base.rsplit(".", 1)
        base = f"{stem}.{ext[1][:16]}" if len(ext) == 2 else stem
    return base


def validate_upload(filename: str, size_bytes: int | None = None) -> str:
    """校验扩展名白名单与大小上限，返回净化后的文件名。"""
    clean = sanitize_filename(filename)
    ext = clean.rsplit(".", 1)
    if len(ext) != 2 or ext[1].lower() not in ALLOWED_EXTS:
        raise HTTPException(422, f"不支持的文件类型，允许：{'/'.join(sorted(ALLOWED_EXTS))}")
    if size_bytes is not None and size_bytes > MAX_UPLOAD_BYTES:
        raise HTTPException(413, f"文件超过 {MAX_UPLOAD_BYTES // (1024 * 1024)}MB 上限")
    return clean


def save_stream(upload: UploadFile) -> tuple[str, int, str]:
    """将上传文件流式写入本地存储，返回 (oss_key, 大小, 净化文件名)。

    oss_key 形如 ``local/2026/09/05/<uuid>.<ext>``，与 OBS 命名空间隔离，
    下载时据此解析磁盘路径。
    """
    original = sanitize_filename(upload.filename or "file")
    validate_upload(original)
    day = datetime.utcnow()
    sub = f"{day.year}/{day.month:02d}/{day.day:02d}"
    stem = uuid.uuid4().hex
    ext = original.rsplit(".", 1)[1].lower()
    key = f"local/{sub}/{stem}.{ext}"

    target = storage_dir() / sub
    target.mkdir(parents=True, exist_ok=True)
    path = target / f"{stem}.{ext}"

    written = 0
    try:
        with path.open("wb") as out:
            while chunk := upload.file.read(1024 * 1024):
                written += len(chunk)
                if written > MAX_UPLOAD_BYTES:
                    raise HTTPException(413, f"文件超过 {MAX_UPLOAD_BYTES // (1024 * 1024)}MB 上限")
                out.write(chunk)
    except HTTPException:
        path.unlink(missing_ok=True)
        raise
    if written == 0:
        path.unlink(missing_ok=True)
        raise HTTPException(422, "文件内容为空")

    # 保留原文件名供下载时还原（stem.sidecar）
    (target / f"{stem}.name").write_text(original, encoding="utf-8")
    return key, written, original


def resolve_local_path(oss_key: str) -> Path | None:
    """将 oss_key 解析为本地磁盘路径；非 local/ 前缀（OBS 对象）返回 None。"""
    if not oss_key or not oss_key.startswith("local/"):
        return None
    rel = oss_key[len("local/"):]
    path = (storage_dir() / rel).resolve()
    root = storage_dir().resolve()
    if root not in path.parents and path != root:
        return None  # 路径穿越防护
    if not path.is_file():
        return None
    return path


def original_name_for(oss_key: str) -> str:
    """读取 sidecar 原始文件名（无则回退 key 尾段）。"""
    path = resolve_local_path(oss_key)
    if path is None:
        return oss_key.rsplit("/", 1)[-1]
    side = path.with_suffix(".name")
    if side.is_file():
        try:
            return side.read_text(encoding="utf-8").strip() or path.name
        except OSError:
            return path.name
    return path.name


def storage_usage_bytes() -> int:
    """存储目录总字节数（管理端展示用）。"""
    return sum(f.stat().st_size for f in storage_dir().rglob("*") if f.is_file())
