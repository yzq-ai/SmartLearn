from __future__ import annotations

from datetime import datetime

from sqlalchemy import JSON, Float, Integer, String, Text, DateTime, ForeignKey, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class Course(Base):
    __tablename__ = "course"

    id: Mapped[int] = mapped_column(primary_key=True)
    course_code: Mapped[str | None] = mapped_column(String(30), unique=True, nullable=True)
    title: Mapped[str] = mapped_column(String(200))
    description: Mapped[str] = mapped_column(Text, default="")
    cover_url: Mapped[str | None] = mapped_column(String(255), nullable=True)
    teacher: Mapped[str] = mapped_column(String(100), default="")
    teacher_id: Mapped[int | None] = mapped_column(ForeignKey("sys_user.id"), nullable=True)
    semester: Mapped[str | None] = mapped_column(String(20), nullable=True)
    skill_tags: Mapped[list | None] = mapped_column(JSON, nullable=True)
    status: Mapped[int] = mapped_column(Integer, default=0)
    student_count: Mapped[int] = mapped_column(Integer, default=0)
    # 课表信息（教师录入，学生端「我的课程」展示）
    start_date: Mapped[str | None] = mapped_column(String(20), nullable=True)      # 起始日期 2026-09-01
    end_date: Mapped[str | None] = mapped_column(String(20), nullable=True)        # 截止日期
    class_time: Mapped[str | None] = mapped_column(String(100), nullable=True)      # 上课时间 周一 1-2 节
    location: Mapped[str | None] = mapped_column(String(100), nullable=True)      # 上课地点 教学楼 A301
    exam_time: Mapped[str | None] = mapped_column(String(100), nullable=True)      # 考试时间
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    chapters = relationship("Chapter", back_populates="course", cascade="all, delete-orphan")


class Chapter(Base):
    __tablename__ = "chapter"

    id: Mapped[int] = mapped_column(primary_key=True)
    course_id: Mapped[int] = mapped_column(ForeignKey("course.id"))
    title: Mapped[str] = mapped_column(String(200))
    description: Mapped[str] = mapped_column(Text, default="")
    position: Mapped[int] = mapped_column("sort_order", Integer, default=0)
    course = relationship("Course", back_populates="chapters")
    sections = relationship(
        "Section", back_populates="chapter", cascade="all, delete-orphan",
        order_by="Section.position",
    )


class Resource(Base):
    __tablename__ = "resource"

    id: Mapped[int] = mapped_column(primary_key=True)
    file_name: Mapped[str] = mapped_column(String(200))
    file_type: Mapped[str | None] = mapped_column(String(20), nullable=True)
    file_size: Mapped[int | None] = mapped_column(Integer, nullable=True)
    oss_key: Mapped[str] = mapped_column(String(255))
    hls_url: Mapped[str | None] = mapped_column(String(255), nullable=True)
    duration: Mapped[int | None] = mapped_column(Integer, nullable=True)
    uploader_id: Mapped[int] = mapped_column(ForeignKey("sys_user.id"))
    status: Mapped[int] = mapped_column(Integer, default=1)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)


class Section(Base):
    __tablename__ = "section"

    id: Mapped[int] = mapped_column(primary_key=True)
    chapter_id: Mapped[int] = mapped_column(ForeignKey("chapter.id"), index=True)
    title: Mapped[str] = mapped_column(String(200))
    type: Mapped[str] = mapped_column(String(10), default="TEXT")
    resource_id: Mapped[int | None] = mapped_column(ForeignKey("resource.id"), nullable=True)
    content: Mapped[str] = mapped_column(Text, default="")
    video_url: Mapped[str | None] = mapped_column(String(500), nullable=True)
    duration_minutes: Mapped[int] = mapped_column(Integer, default=0)
    duration_sec: Mapped[int] = mapped_column(Integer, default=0)
    position: Mapped[int] = mapped_column("sort_order", Integer, default=0)
    status: Mapped[int] = mapped_column(Integer, default=1)
    chapter = relationship("Chapter", back_populates="sections")
    __table_args__ = (UniqueConstraint("chapter_id", "sort_order", name="uq_section_position"),)


class CourseEnrollment(Base):
    __tablename__ = "course_enrollment"

    id: Mapped[int] = mapped_column(primary_key=True)
    course_id: Mapped[int] = mapped_column(ForeignKey("course.id"))
    user_id: Mapped[int] = mapped_column(ForeignKey("sys_user.id"))
    class_name: Mapped[str | None] = mapped_column(String(50), nullable=True)
    progress_pct: Mapped[float] = mapped_column(Float, default=0)
    enrolled_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    __table_args__ = (UniqueConstraint("course_id", "user_id", name="uq_course_user"),)


class CourseSkillTag(Base):
    __tablename__ = "course_skill_tag"

    id: Mapped[int] = mapped_column(primary_key=True)
    course_id: Mapped[int] = mapped_column(ForeignKey("course.id"))
    tag_name: Mapped[str] = mapped_column(String(50))
    weight: Mapped[float] = mapped_column(Float, default=1.0)
    __table_args__ = (UniqueConstraint("course_id", "tag_name", name="uq_course_tag"),)


__all__ = ["Course", "Chapter", "Resource", "Section", "CourseEnrollment", "CourseSkillTag"]
