from __future__ import annotations

from datetime import date, datetime

from sqlalchemy import JSON, Integer, String, Text, DateTime, Date, ForeignKey, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


class AiChatLog(Base):
    __tablename__ = "ai_chat_log"

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("sys_user.id"))
    scene: Mapped[str] = mapped_column(String(20))
    ref_type: Mapped[str | None] = mapped_column(String(20), nullable=True)
    ref_id: Mapped[int | None] = mapped_column(Integer, nullable=True)
    input_text: Mapped[str | None] = mapped_column(Text, nullable=True)
    output_text: Mapped[str | None] = mapped_column(Text, nullable=True)
    refs: Mapped[list | None] = mapped_column(JSON, nullable=True)
    model_name: Mapped[str | None] = mapped_column(String(50), nullable=True)
    token_in: Mapped[int | None] = mapped_column(Integer, nullable=True)
    token_out: Mapped[int | None] = mapped_column(Integer, nullable=True)
    latency_ms: Mapped[int | None] = mapped_column(Integer, nullable=True)
    feedback: Mapped[int | None] = mapped_column(Integer, nullable=True)
    is_blocked: Mapped[int] = mapped_column(Integer, default=0)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)


class StudyPlan(Base):
    __tablename__ = "study_plan"

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("sys_user.id"))
    goal: Mapped[str | None] = mapped_column(String(200), nullable=True)
    plan_json: Mapped[dict] = mapped_column(JSON)
    ai_generated: Mapped[int] = mapped_column(Integer, default=1)
    status: Mapped[str] = mapped_column(String(10), default="ACTIVE")
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)


class StatDailyLearning(Base):
    __tablename__ = "stat_daily_learning"

    id: Mapped[int] = mapped_column(primary_key=True)
    stat_date: Mapped[date] = mapped_column(Date)
    scope_type: Mapped[str] = mapped_column(String(10))
    scope_id: Mapped[int | None] = mapped_column(Integer, nullable=True)
    metrics: Mapped[dict | None] = mapped_column(JSON, nullable=True)
    __table_args__ = (UniqueConstraint("scope_type", "scope_id", "stat_date", name="uq_scope_date"),)


__all__ = ["AiChatLog", "StudyPlan", "StatDailyLearning"]
