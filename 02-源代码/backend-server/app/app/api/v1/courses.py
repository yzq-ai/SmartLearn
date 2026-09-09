from __future__ import annotations

import logging

from fastapi import APIRouter, Depends, HTTPException, UploadFile
from fastapi.responses import FileResponse
from pydantic import BaseModel, Field
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.auth import current_user, require_roles
from app.core.response import success
from app.database import get_db
from app.models import Chapter, Course as CourseModel, Progress, Resource, Section
from app.schemas import (
    ChapterRead,
    CourseCreate,
    CourseDetail,
    ProgressRead,
    ProgressUpdate,
    ResourceCreate,
    SectionRead,
)
from app.services import local_store

router = APIRouter()
logger = logging.getLogger("smartlearn.courses")


def course_out(course):
    return {
        "id": course.id,
        "title": course.title,
        "description": course.description,
        "teacher": course.teacher,
        "teacher_id": course.teacher_id,
        "semester": course.semester or "",
        "student_count": course.student_count,
        "skill_tags": course.skill_tags or [],
        # 课表信息（教师录入；学生端「我的课程」展示）
        "start_date": course.start_date or "",
        "end_date": course.end_date or "",
        "class_time": course.class_time or "",
        "location": course.location or "",
        "exam_time": course.exam_time or "",
        "chapters": [chapter.title for chapter in sorted(course.chapters, key=lambda item: item.position)],
    }


@router.get("/courses", tags=["courses"])
async def courses(db: AsyncSession = Depends(get_db)):
    # 排除教研区哨兵行（id=0，仅供教师教研讨论挂靠，不作为课程展示）
    rows = (
        await db.execute(
            select(CourseModel).options(selectinload(CourseModel.chapters)).where(CourseModel.id != 0)
        )
    ).scalars().all()
    out = []
    for course in rows:
        try:
            out.append(course_out(course))
        except Exception:
            # 单行坏数据（如非法 JSON 列）不拖垮整个课程列表
            logger.warning("course_out_failed", extra={"course_id": course.id})
    return success(out)


# 需求 6：教师课程内容管理（章节/小节 CRUD + 视频上传）
# ══════════════════════════════════════════════════════════════════

class ChapterCreate(BaseModel):
    title: str = Field(min_length=1, max_length=200)
    description: str = ""
    position: int | None = None


class ChapterUpdate(BaseModel):
    title: str | None = None
    description: str | None = None
    position: int | None = None


class SectionCreate(BaseModel):
    title: str = Field(min_length=1, max_length=200)
    type: str = "TEXT"           # TEXT | VIDEO | QUIZ
    content: str = ""
    video_url: str | None = None
    duration_minutes: int = 0
    duration_sec: int = 0
    position: int | None = None


class SectionUpdate(BaseModel):
    title: str | None = None
    type: str | None = None
    content: str | None = None
    video_url: str | None = None
    duration_minutes: int | None = None
    duration_sec: int | None = None
    position: int | None = None


async def _ensure_course_teacher(db: AsyncSession, course_id: int, user) -> None:
    """校验课程存在且当前用户是授课教师（管理员放行）。"""
    course = await db.get(CourseModel, course_id)
    if not course:
        raise HTTPException(404, "课程不存在")
    if user.role == "ADMIN":
        return
    if user.role == "TEACHER" and (course.teacher_id == user.id or course.teacher == user.real_name):
        return
    raise HTTPException(403, "仅授课教师可管理该课程")


def _chapter_out(ch: Chapter) -> dict:
    return {
        "id": ch.id, "course_id": ch.course_id, "title": ch.title,
        "description": ch.description, "position": ch.position,
        "sections": [
            {
                "id": s.id, "chapter_id": s.chapter_id, "title": s.title, "type": s.type,
                "content": s.content, "video_url": s.video_url or "",
                "duration_minutes": s.duration_minutes, "duration_sec": s.duration_sec,
                "position": s.position, "status": s.status,
            }
            for s in sorted(ch.sections, key=lambda x: x.position)
        ],
    }


@router.get("/courses/manage/{course_id}/chapters", tags=["courses-manage"])
async def manage_list_chapters(course_id: int, db: AsyncSession = Depends(get_db), user=Depends(require_roles("TEACHER", "ADMIN"))):
    """教师课程内容管理：完整章节树（含小节正文与视频地址）。"""
    await _ensure_course_teacher(db, course_id, user)
    chapters = (
        await db.execute(
            select(Chapter)
            .options(selectinload(Chapter.sections))
            .where(Chapter.course_id == course_id)
            .order_by(Chapter.position)
        )
    ).scalars().all()
    return success([_chapter_out(ch) for ch in chapters])


@router.post("/courses/manage/{course_id}/chapters", tags=["courses-manage"])
async def manage_create_chapter(course_id: int, payload: ChapterCreate, db: AsyncSession = Depends(get_db), user=Depends(require_roles("TEACHER", "ADMIN"))):
    await _ensure_course_teacher(db, course_id, user)
    if payload.position is None:
        last = (await db.execute(
            select(Chapter).where(Chapter.course_id == course_id).order_by(Chapter.position.desc()).limit(1)
        )).scalar_one_or_none()
        payload.position = (last.position + 1) if last else 1
    chapter = Chapter(course_id=course_id, title=payload.title, description=payload.description, position=payload.position)
    db.add(chapter)
    await db.commit()
    await db.refresh(chapter)
    # 新章节无小节，避免 sections 关系 lazy load（异步上下文不可用）
    return success({
        "id": chapter.id, "course_id": chapter.course_id, "title": chapter.title,
        "description": chapter.description, "position": chapter.position, "sections": [],
    })


@router.put("/courses/manage/chapters/{chapter_id}", tags=["courses-manage"])
async def manage_update_chapter(chapter_id: int, payload: ChapterUpdate, db: AsyncSession = Depends(get_db), user=Depends(require_roles("TEACHER", "ADMIN"))):
    chapter = await db.get(Chapter, chapter_id)
    if not chapter:
        raise HTTPException(404, "章节不存在")
    await _ensure_course_teacher(db, chapter.course_id, user)
    if payload.title is not None:
        chapter.title = payload.title
    if payload.description is not None:
        chapter.description = payload.description
    if payload.position is not None:
        chapter.position = payload.position
    await db.commit()
    return success({"id": chapter.id, "updated": True})


@router.delete("/courses/manage/chapters/{chapter_id}", tags=["courses-manage"])
async def manage_delete_chapter(chapter_id: int, db: AsyncSession = Depends(get_db), user=Depends(require_roles("TEACHER", "ADMIN"))):
    chapter = await db.get(Chapter, chapter_id)
    if not chapter:
        raise HTTPException(404, "章节不存在")
    await _ensure_course_teacher(db, chapter.course_id, user)
    await db.delete(chapter)
    await db.commit()
    return success({"id": chapter_id, "deleted": True})


@router.post("/courses/manage/{chapter_id}/sections", tags=["courses-manage"])
async def manage_create_section(chapter_id: int, payload: SectionCreate, db: AsyncSession = Depends(get_db), user=Depends(require_roles("TEACHER", "ADMIN"))):
    chapter = await db.get(Chapter, chapter_id)
    if not chapter:
        raise HTTPException(404, "章节不存在")
    await _ensure_course_teacher(db, chapter.course_id, user)
    if payload.position is None:
        last = (await db.execute(
            select(Section).where(Section.chapter_id == chapter_id).order_by(Section.position.desc()).limit(1)
        )).scalar_one_or_none()
        payload.position = (last.position + 1) if last else 1
    section = Section(
        chapter_id=chapter_id, title=payload.title, type=payload.type,
        content=payload.content, video_url=payload.video_url,
        duration_minutes=payload.duration_minutes, duration_sec=payload.duration_sec,
        position=payload.position,
    )
    db.add(section)
    try:
        await db.commit()
    except IntegrityError:
        await db.rollback()
        raise HTTPException(422, "小节序号冲突，请刷新后重试")
    await db.refresh(section)
    return success({
        "id": section.id, "chapter_id": section.chapter_id, "title": section.title,
        "type": section.type, "content": section.content, "video_url": section.video_url or "",
        "duration_minutes": section.duration_minutes, "duration_sec": section.duration_sec,
        "position": section.position, "status": section.status,
    })


@router.put("/courses/manage/sections/{section_id}", tags=["courses-manage"])
async def manage_update_section(section_id: int, payload: SectionUpdate, db: AsyncSession = Depends(get_db), user=Depends(require_roles("TEACHER", "ADMIN"))):
    section = await db.get(Section, section_id)
    if not section:
        raise HTTPException(404, "小节不存在")
    chapter = await db.get(Chapter, section.chapter_id)
    await _ensure_course_teacher(db, chapter.course_id, user)
    if payload.title is not None:
        section.title = payload.title
    if payload.type is not None:
        section.type = payload.type
    if payload.content is not None:
        section.content = payload.content
    if payload.video_url is not None:
        section.video_url = payload.video_url
    if payload.duration_minutes is not None:
        section.duration_minutes = payload.duration_minutes
    if payload.duration_sec is not None:
        section.duration_sec = payload.duration_sec
    if payload.position is not None:
        section.position = payload.position
    await db.commit()
    return success({"id": section.id, "updated": True})


@router.delete("/courses/manage/sections/{section_id}", tags=["courses-manage"])
async def manage_delete_section(section_id: int, db: AsyncSession = Depends(get_db), user=Depends(require_roles("TEACHER", "ADMIN"))):
    section = await db.get(Section, section_id)
    if not section:
        raise HTTPException(404, "小节不存在")
    chapter = await db.get(Chapter, section.chapter_id)
    await _ensure_course_teacher(db, chapter.course_id, user)
    await db.delete(section)
    await db.commit()
    return success({"id": section_id, "deleted": True})


@router.post("/courses/manage/{course_id}/video-upload-token", tags=["courses-manage"])
async def manage_video_upload_token(course_id: int, db: AsyncSession = Depends(get_db), user=Depends(require_roles("TEACHER", "ADMIN"))):
    """章节视频上传凭证：本地存储模式直接返回上传端点说明（与资源上传一致）。"""
    await _ensure_course_teacher(db, course_id, user)
    return success({
        "mode": "local",
        "upload_url": "/api/v1/courses/resources/upload",
        "note": "multipart 字段 file；上传后把返回的 oss_key 填入小节 video_url 或作为 hls_url",
    })


@router.get("/courses/{course_id}", tags=["courses"])
async def course_detail(course_id: int, db: AsyncSession = Depends(get_db)):
    course = (
        await db.execute(
            select(CourseModel)
            .options(selectinload(CourseModel.chapters).selectinload(Chapter.sections))
            .where(CourseModel.id == course_id)
        )
    ).scalar_one_or_none()
    if not course:
        raise HTTPException(404, "课程不存在")
    return success(CourseDetail.model_validate(course).model_dump())


@router.get("/courses/{course_id}/chapters/{chapter_id}", tags=["courses"])
async def chapter_detail(course_id: int, chapter_id: int, db: AsyncSession = Depends(get_db)):
    chapter = (
        await db.execute(
            select(Chapter).options(selectinload(Chapter.sections)).where(
                Chapter.id == chapter_id, Chapter.course_id == course_id
            )
        )
    ).scalar_one_or_none()
    if not chapter:
        raise HTTPException(404, "章节不存在")
    return success(ChapterRead.model_validate(chapter).model_dump())


@router.get("/courses/{course_id}/chapters/{chapter_id}/sections/{section_id}", tags=["courses"])
async def section_detail(course_id: int, chapter_id: int, section_id: int, db: AsyncSession = Depends(get_db)):
    section = (
        await db.execute(
            select(Section).join(Chapter).where(
                Section.id == section_id,
                Section.chapter_id == chapter_id,
                Chapter.course_id == course_id,
            )
        )
    ).scalar_one_or_none()
    if not section:
        raise HTTPException(404, "小节不存在")
    return success(SectionRead.model_validate(section).model_dump())


@router.post("/courses", tags=["courses"])
async def create_course(payload: CourseCreate, db: AsyncSession = Depends(get_db), user=Depends(require_roles("TEACHER", "ADMIN"))):
    teacher_name = payload.teacher or user.real_name or user.username
    course = CourseModel(title=payload.title, description=payload.description, teacher=teacher_name, teacher_id=user.id)
    db.add(course)
    await db.commit()
    await db.refresh(course)
    course.chapters = []
    return success(course_out(course))


@router.put("/courses/{course_id}", tags=["courses"])
async def update_course(course_id: int, payload: CourseCreate, db: AsyncSession = Depends(get_db), user=Depends(require_roles("TEACHER", "ADMIN"))):
    course = await db.get(CourseModel, course_id)
    if not course:
        raise HTTPException(404, "课程不存在")
    course.title = payload.title
    course.description = payload.description
    await db.commit()
    await db.refresh(course)
    return success({"id": course.id, "title": course.title, "description": course.description, "teacher": course.teacher})


class ScheduleUpdate(BaseModel):
    """教师录入课表：起止日期 / 上课时间 / 地点 / 考试时间。"""
    start_date: str | None = Field(default=None, max_length=20)
    end_date: str | None = Field(default=None, max_length=20)
    class_time: str | None = Field(default=None, max_length=100)
    location: str | None = Field(default=None, max_length=100)
    exam_time: str | None = Field(default=None, max_length=100)


@router.put("/courses/{course_id}/schedule", tags=["courses"])
async def update_course_schedule(course_id: int, payload: ScheduleUpdate, db: AsyncSession = Depends(get_db), user=Depends(require_roles("TEACHER", "ADMIN"))):
    course = await db.get(CourseModel, course_id)
    if not course:
        raise HTTPException(404, "课程不存在")
    for field in ("start_date", "end_date", "class_time", "location", "exam_time"):
        value = getattr(payload, field)
        if value is not None:
            setattr(course, field, value.strip() or None)
    await db.commit()
    await db.refresh(course)
    return success({
        "id": course.id, "start_date": course.start_date, "end_date": course.end_date,
        "class_time": course.class_time, "location": course.location, "exam_time": course.exam_time,
    })


@router.get("/my/courses", tags=["courses"])
async def my_courses(db: AsyncSession = Depends(get_db), user=Depends(current_user)):
    """我的课程：学生=已选课程（含课表/教师/考试时间）；教师=我授课的课程。"""
    from app.models import CourseEnrollment

    if user.role == "TEACHER" or user.role == "ADMIN":
        rows = (
            await db.execute(
                select(CourseModel).options(selectinload(CourseModel.chapters)).where(CourseModel.teacher_id == user.id)
            )
        ).scalars().all()
        return success([course_out(c) for c in rows])
    enrolled_ids = (
        await db.execute(select(CourseEnrollment.course_id).where(CourseEnrollment.user_id == user.id))
    ).scalars().all()
    if not enrolled_ids:
        return success([])
    rows = (
        await db.execute(
            select(CourseModel).options(selectinload(CourseModel.chapters)).where(CourseModel.id.in_(enrolled_ids))
        )
    ).scalars().all()
    return success([course_out(c) for c in rows])


@router.post("/resources/upload-token", tags=["courses"])
async def resource_upload_token(db: AsyncSession = Depends(get_db), user=Depends(require_roles("TEACHER", "ADMIN"))):
    """获取上传凭证：OBS 配置时返回预签名直传地址；本地模式返回 multipart 直传端点。"""
    from app.services.obs import create_upload_token

    token = create_upload_token()
    if not token.get("upload_url"):
        # 本地模式：指引客户端走 multipart 直传端点
        token["upload_url"] = "/api/v1/resources/upload"
        token["storage"] = "local"
    return success(token)


@router.post("/resources", tags=["courses"])
async def create_resource(payload: ResourceCreate, db: AsyncSession = Depends(get_db), user=Depends(require_roles("TEACHER", "ADMIN"))):
    resource = Resource(
        file_name=payload.file_name,
        file_type=payload.file_type,
        file_size=payload.file_size,
        oss_key=payload.oss_key,
        duration=payload.duration,
        uploader_id=user.id,
        status=1,
    )
    db.add(resource)
    await db.commit()
    await db.refresh(resource)
    return success({"id": resource.id, "file_name": resource.file_name, "oss_key": resource.oss_key})


@router.post("/resources/upload", tags=["courses"])
async def upload_resource_direct(
    file: UploadFile,
    course_id: int | None = None,
    chapter_id: int | None = None,
    db: AsyncSession = Depends(get_db),
    user=Depends(require_roles("TEACHER", "ADMIN")),
):
    """本地/未配置 OBS 模式的真实文件上传：multipart 流式落盘 + 元数据登记。

    扩展名白名单 + 50MB 上限 + 文件名净化（防路径穿越），返回可下载地址。
    """
    oss_key, size, clean_name = local_store.save_stream(file)
    ext = clean_name.rsplit(".", 1)[1].lower()
    resource = Resource(
        file_name=clean_name,
        file_type="video" if ext in ("mp4", "mov", "avi", "mkv", "webm") else "doc",
        file_size=size,
        oss_key=oss_key,
        uploader_id=user.id,
        status=1,
    )
    db.add(resource)
    await db.commit()
    await db.refresh(resource)
    return success({
        "id": resource.id,
        "file_name": clean_name,
        "file_type": resource.file_type,
        "file_size": size,
        "oss_key": oss_key,
        "download_url": f"/api/v1/resources/{resource.id}/download",
    })


@router.get("/resources/list", tags=["courses"])
async def list_resources(
    db: AsyncSession = Depends(get_db),
    user=Depends(current_user),
    file_type: str | None = None,
    page: int = 1,
    page_size: int = 20,
):
    """资源列表（登录可见）：学生下载学习资料；教师管理视角。"""
    from sqlalchemy import func

    page = max(1, page)
    page_size = max(1, min(100, page_size))
    filters = [Resource.status == 1]
    if file_type:
        filters.append(Resource.file_type == file_type)
    base = select(Resource).where(*filters)
    total = (await db.execute(select(func.count()).select_from(base.subquery()))).scalar() or 0
    rows = (
        await db.execute(base.order_by(Resource.id.desc()).offset((page - 1) * page_size).limit(page_size))
    ).scalars().all()
    return success({
        "items": [
            {
                "id": r.id,
                "file_name": r.file_name,
                "file_type": r.file_type,
                "file_size": r.file_size,
                "oss_key": r.oss_key,
                "duration": r.duration,
                "download_url": f"/api/v1/resources/{r.id}/download",
                "is_local": bool((r.oss_key or "").startswith("local/")),
                "course_id": None,
            }
            for r in rows
        ],
        "total": total,
        "page": page,
        "page_size": page_size,
    })


@router.get("/resources/{resource_id}/download", tags=["courses"])
async def download_resource(
    resource_id: int,
    db: AsyncSession = Depends(get_db),
    user=Depends(current_user),
):
    """资源下载：本地存储回源文件；OBS 模式返回 302 预签名跳转。"""
    resource = await db.get(Resource, resource_id)
    if not resource or resource.status != 1:
        raise HTTPException(404, "资源不存在或已下线")

    path = local_store.resolve_local_path(resource.oss_key or "")
    if path is not None:
        original = local_store.original_name_for(resource.oss_key or "")
        return FileResponse(
            path,
            filename=original,
            media_type="application/octet-stream",
        )
    # OBS 模式：生成临时预签名下载 URL
    if resource.oss_key:
        from app.services.obs import create_upload_token, _configured

        if _configured():
            # 预签名 GET 与 PUT 同一函数族；这里用 boto3 生成下载链接
            from app.services.obs import _client
            from app.core.config import settings as _s

            url = _client().generate_presigned_url(
                "get_object",
                Params={"Bucket": _s.obs_bucket, "Key": resource.oss_key},
                ExpiresIn=3600,
            )
            from fastapi.responses import RedirectResponse

            return RedirectResponse(url)
    raise HTTPException(404, "资源文件不可用（存储未配置或文件丢失）")


@router.get("/progress", tags=["progress"])
async def get_progress(db: AsyncSession = Depends(get_db), user=Depends(current_user)):
    rows = (await db.execute(select(Progress).where(Progress.user_id == user.id))).scalars().all()
    return success([ProgressRead.model_validate(row).model_dump() for row in rows])


@router.put("/progress/{course_id}", tags=["progress"])
async def update_progress(
    course_id: int,
    payload: ProgressUpdate,
    db: AsyncSession = Depends(get_db),
    user=Depends(current_user),
):
    if not await db.get(CourseModel, course_id):
        raise HTTPException(404, "课程不存在")
    if payload.chapter_id is not None:
        chapter = await db.get(Chapter, payload.chapter_id)
        if not chapter or chapter.course_id != course_id:
            raise HTTPException(422, "章节不属于该课程")
    if payload.section_id is not None:
        section = await db.get(Section, payload.section_id)
        if not section or section.chapter_id != payload.chapter_id:
            raise HTTPException(422, "小节不属于该章节")

    progress = (
        await db.execute(
            select(Progress)
            .where(Progress.user_id == user.id, Progress.course_id == course_id)
            .with_for_update()
        )
    ).scalar_one_or_none()
    if not progress:
        progress = Progress(user_id=user.id, course_id=course_id)
        db.add(progress)
    progress.percent = payload.percent
    progress.chapter_id = payload.chapter_id
    progress.section_id = payload.section_id
    try:
        await db.commit()
    except IntegrityError:
        await db.rollback()
        progress = (
            await db.execute(
                select(Progress).where(Progress.user_id == user.id, Progress.course_id == course_id)
            )
        ).scalar_one()
        progress.percent = payload.percent
        progress.chapter_id = payload.chapter_id
        progress.section_id = payload.section_id
        await db.commit()
    await db.refresh(progress)
    return success(ProgressRead.model_validate(progress).model_dump())


# ══════════════════════════════════════════════════════════════════