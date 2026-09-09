"""Course business logic: CRUD, enrollment, chapter/section management, progress.

All DB-mutating functions accept an AsyncSession for dependency injection;
pure helpers have no DB dependency and are directly unit-testable.
"""
from __future__ import annotations

from fastapi import HTTPException
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models import Chapter, Course as CourseModel, Progress, Section
from app.schemas import ChapterRead, CourseDetail, ProgressRead, SectionRead


def course_out(course) -> dict:
    return {
        "id": course.id,
        "title": course.title,
        "description": course.description,
        "teacher": course.teacher,
        "chapters": [chapter.title for chapter in sorted(course.chapters, key=lambda item: item.position)],
    }


async def list_courses(db: AsyncSession) -> list[dict]:
    rows = (
        await db.execute(select(CourseModel).options(selectinload(CourseModel.chapters)))
    ).scalars().all()
    return [course_out(course) for course in rows]


async def get_course_detail(db: AsyncSession, course_id: int) -> dict:
    course = (
        await db.execute(
            select(CourseModel)
            .options(selectinload(CourseModel.chapters).selectinload(Chapter.sections))
            .where(CourseModel.id == course_id)
        )
    ).scalar_one_or_none()
    if not course:
        raise HTTPException(404, "课程不存在")
    return CourseDetail.model_validate(course).model_dump()


async def get_chapter_detail(db: AsyncSession, course_id: int, chapter_id: int) -> dict:
    chapter = (
        await db.execute(
            select(Chapter).options(selectinload(Chapter.sections)).where(
                Chapter.id == chapter_id, Chapter.course_id == course_id
            )
        )
    ).scalar_one_or_none()
    if not chapter:
        raise HTTPException(404, "章节不存在")
    return ChapterRead.model_validate(chapter).model_dump()


async def get_section_detail(db: AsyncSession, course_id: int, chapter_id: int, section_id: int) -> dict:
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
    return SectionRead.model_validate(section).model_dump()


async def create_course(db: AsyncSession, payload, user) -> dict:
    teacher_name = payload.teacher or user.real_name or user.username
    course = CourseModel(
        title=payload.title, description=payload.description,
        teacher=teacher_name, teacher_id=user.id,
    )
    db.add(course)
    await db.commit()
    await db.refresh(course)
    course.chapters = []
    return course_out(course)


async def update_course(db: AsyncSession, course_id: int, payload) -> dict:
    course = await db.get(CourseModel, course_id)
    if not course:
        raise HTTPException(404, "课程不存在")
    course.title = payload.title
    course.description = payload.description
    await db.commit()
    await db.refresh(course)
    return {"id": course.id, "title": course.title, "description": course.description, "teacher": course.teacher}


async def get_progress_list(db: AsyncSession, user_id: int) -> list[dict]:
    rows = (await db.execute(select(Progress).where(Progress.user_id == user_id))).scalars().all()
    return [ProgressRead.model_validate(row).model_dump() for row in rows]


async def update_progress(db: AsyncSession, user_id: int, course_id: int, payload) -> dict:
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
            .where(Progress.user_id == user_id, Progress.course_id == course_id)
            .with_for_update()
        )
    ).scalar_one_or_none()
    if not progress:
        progress = Progress(user_id=user_id, course_id=course_id)
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
                select(Progress).where(Progress.user_id == user_id, Progress.course_id == course_id)
            )
        ).scalar_one()
        progress.percent = payload.percent
        progress.chapter_id = payload.chapter_id
        progress.section_id = payload.section_id
        await db.commit()
    await db.refresh(progress)
    return ProgressRead.model_validate(progress).model_dump()
