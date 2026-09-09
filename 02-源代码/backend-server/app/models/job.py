from __future__ import annotations

from datetime import datetime

from sqlalchemy import JSON, Boolean, Integer, String, Text, DateTime, ForeignKey, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class Company(Base):
    __tablename__ = "company"

    id: Mapped[int] = mapped_column(primary_key=True)
    name: Mapped[str] = mapped_column(String(100))
    industry: Mapped[str | None] = mapped_column(String(50), nullable=True)
    scale: Mapped[str | None] = mapped_column(String(30), nullable=True)
    website: Mapped[str | None] = mapped_column(String(200), nullable=True)
    logo_url: Mapped[str | None] = mapped_column(String(255), nullable=True)
    intro: Mapped[str | None] = mapped_column(Text, nullable=True)
    license_oss_key: Mapped[str | None] = mapped_column(String(255), nullable=True)
    verify_status: Mapped[int] = mapped_column(Integer, default=0)
    reject_reason: Mapped[str | None] = mapped_column(String(200), nullable=True)
    verified_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    created_by: Mapped[int] = mapped_column(ForeignKey("sys_user.id"))


class JobSkillTag(Base):
    __tablename__ = "job_skill_tag"

    id: Mapped[int] = mapped_column(primary_key=True)
    name: Mapped[str] = mapped_column(String(50), unique=True)
    category: Mapped[str | None] = mapped_column(String(30), nullable=True)


class JobPosting(Base):
    __tablename__ = "job_posting"

    id: Mapped[int] = mapped_column(primary_key=True)
    company_id: Mapped[int | None] = mapped_column(ForeignKey("company.id"), nullable=True)
    company: Mapped[str] = mapped_column(String(200), default="")
    title: Mapped[str] = mapped_column(String(200))
    job_type: Mapped[str] = mapped_column(String(10), default="INTERNSHIP")
    city: Mapped[str | None] = mapped_column(String(50), nullable=True)
    salary_min: Mapped[int | None] = mapped_column(Integer, nullable=True)
    salary_max: Mapped[int | None] = mapped_column(Integer, nullable=True)
    education_req: Mapped[str | None] = mapped_column(String(20), nullable=True)
    headcount: Mapped[int] = mapped_column(Integer, default=1)
    description: Mapped[str] = mapped_column(Text, default="")
    required_skills: Mapped[str] = mapped_column(Text, default="")
    skill_weights: Mapped[dict | None] = mapped_column(JSON, nullable=True)
    major_req: Mapped[str | None] = mapped_column(String(100), nullable=True)
    deadline: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    review_status: Mapped[int] = mapped_column(Integer, default=0)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    view_count: Mapped[int] = mapped_column(Integer, default=0)
    created_by: Mapped[int | None] = mapped_column(ForeignKey("sys_user.id"), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)


class StudentProfile(Base):
    __tablename__ = "student_profile"

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("sys_user.id"), unique=True)
    skill_scores: Mapped[dict | None] = mapped_column(JSON, nullable=True)
    radar_data: Mapped[dict | None] = mapped_column(JSON, nullable=True)
    self_tags: Mapped[list | None] = mapped_column(JSON, nullable=True)
    match_version: Mapped[int] = mapped_column(Integer, default=0)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)


class Resume(Base):
    __tablename__ = "resume"

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("sys_user.id"), index=True)
    title: Mapped[str] = mapped_column(String(100), default="我的简历")
    content: Mapped[dict] = mapped_column(JSON)
    pdf_oss_key: Mapped[str | None] = mapped_column(String(255), nullable=True)
    version: Mapped[int] = mapped_column(Integer, default=1)
    is_default: Mapped[int] = mapped_column(Integer, default=1)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)


class JobApplication(Base):
    __tablename__ = "job_application"

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("sys_user.id"), index=True)
    job_id: Mapped[int] = mapped_column(ForeignKey("job_posting.id"), index=True)
    resume_snapshot: Mapped[dict | None] = mapped_column(JSON, nullable=True)
    status: Mapped[str] = mapped_column(String(12), default="APPLIED")
    reject_reason: Mapped[str | None] = mapped_column(String(200), nullable=True)
    applied_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    status_time: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    job = relationship("JobPosting")
    __table_args__ = (UniqueConstraint("user_id", "job_id", name="uq_job_application"),)


class JobFavorite(Base):
    __tablename__ = "job_favorite"

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("sys_user.id"), index=True)
    job_id: Mapped[int] = mapped_column(ForeignKey("job_posting.id"), index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    job = relationship("JobPosting")
    __table_args__ = (UniqueConstraint("user_id", "job_id", name="uq_job_favorite"),)


class CareerEvent(Base):
    __tablename__ = "career_event"

    id: Mapped[int] = mapped_column(primary_key=True)
    title: Mapped[str] = mapped_column(String(100))
    event_type: Mapped[str | None] = mapped_column(String(10), nullable=True)   # TALK 宣讲会 / FAIR 双选会 / INTERNSHIP 实习实践
    company_id: Mapped[int | None] = mapped_column(ForeignKey("company.id"), nullable=True)
    location: Mapped[str | None] = mapped_column(String(100), nullable=True)
    start_time: Mapped[datetime] = mapped_column(DateTime)
    end_time: Mapped[datetime] = mapped_column(DateTime)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    review_status: Mapped[int] = mapped_column(Integer, default=0)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)


class CareerEventSignup(Base):
    """招聘活动报名记录（一人一活动一次）。"""
    __tablename__ = "career_event_signup"

    id: Mapped[int] = mapped_column(primary_key=True)
    event_id: Mapped[int] = mapped_column(ForeignKey("career_event.id"))
    user_id: Mapped[int] = mapped_column(ForeignKey("sys_user.id"))
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    __table_args__ = (UniqueConstraint("event_id", "user_id", name="uq_event_signup"),)


__all__ = [
    "Company", "JobSkillTag", "JobPosting", "StudentProfile", "Resume",
    "JobApplication", "JobFavorite", "CareerEvent", "CareerEventSignup",
]
