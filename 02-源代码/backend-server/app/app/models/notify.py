from __future__ import annotations

from datetime import datetime

from sqlalchemy import Float, Integer, String, Text, DateTime, ForeignKey, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


class Notification(Base):
    __tablename__ = "notification"

    id: Mapped[int] = mapped_column(primary_key=True)
    type: Mapped[str] = mapped_column(String(20))
    title: Mapped[str] = mapped_column(String(200))
    content: Mapped[str | None] = mapped_column(Text, nullable=True)
    sender_id: Mapped[int | None] = mapped_column(ForeignKey("sys_user.id"), nullable=True)
    target_role: Mapped[str] = mapped_column(String(20), default="ALL")
    target_course_id: Mapped[int | None] = mapped_column(ForeignKey("course.id"), nullable=True)
    jump_page: Mapped[str | None] = mapped_column(String(100), nullable=True)
    jump_param: Mapped[str | None] = mapped_column(String(100), nullable=True)
    push_sent: Mapped[int] = mapped_column(Integer, default=0)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)


class NotificationRead(Base):
    __tablename__ = "notification_read"

    user_id: Mapped[int] = mapped_column(ForeignKey("sys_user.id"), primary_key=True)
    notification_id: Mapped[int] = mapped_column(ForeignKey("notification.id"), primary_key=True)
    read_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)


class SignTask(Base):
    __tablename__ = "sign_task"

    id: Mapped[int] = mapped_column(primary_key=True)
    course_id: Mapped[int] = mapped_column(ForeignKey("course.id"))
    qrcode_token: Mapped[str] = mapped_column(String(64))
    geo_enabled: Mapped[int] = mapped_column(Integer, default=0)
    geo_lat: Mapped[float | None] = mapped_column(Float, nullable=True)
    geo_lng: Mapped[float | None] = mapped_column(Float, nullable=True)
    expire_at: Mapped[datetime] = mapped_column(DateTime)
    created_by: Mapped[int] = mapped_column(ForeignKey("sys_user.id"))


class SignRecord(Base):
    __tablename__ = "sign_record"

    id: Mapped[int] = mapped_column(primary_key=True)
    task_id: Mapped[int] = mapped_column(ForeignKey("sign_task.id"))
    user_id: Mapped[int] = mapped_column(ForeignKey("sys_user.id"))
    sign_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    is_valid: Mapped[int] = mapped_column(Integer, default=1)
    __table_args__ = (UniqueConstraint("task_id", "user_id", name="uq_task_user"),)


class DiscussionPost(Base):
    __tablename__ = "discussion_post"

    id: Mapped[int] = mapped_column(primary_key=True)
    course_id: Mapped[int] = mapped_column(ForeignKey("course.id"))
    user_id: Mapped[int] = mapped_column(ForeignKey("sys_user.id"))
    title: Mapped[str | None] = mapped_column(String(200), nullable=True)
    content: Mapped[str] = mapped_column(Text)
    is_pinned: Mapped[int] = mapped_column(Integer, default=0)
    like_count: Mapped[int] = mapped_column(Integer, default=0)
    review_status: Mapped[int] = mapped_column(Integer, default=1)
    status: Mapped[int] = mapped_column(Integer, default=1)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)


class DiscussionReply(Base):
    __tablename__ = "discussion_reply"

    id: Mapped[int] = mapped_column(primary_key=True)
    post_id: Mapped[int] = mapped_column(ForeignKey("discussion_post.id"))
    user_id: Mapped[int] = mapped_column(ForeignKey("sys_user.id"))
    content: Mapped[str] = mapped_column(Text)
    reply_to_id: Mapped[int | None] = mapped_column(Integer, nullable=True)
    like_count: Mapped[int] = mapped_column(Integer, default=0)
    review_status: Mapped[int] = mapped_column(Integer, default=1)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)


class DiscussionLike(Base):
    """讨论点赞记录（一人一帖一次，幂等）。"""
    __tablename__ = "discussion_like"

    id: Mapped[int] = mapped_column(primary_key=True)
    post_id: Mapped[int] = mapped_column(ForeignKey("discussion_post.id"))
    user_id: Mapped[int] = mapped_column(ForeignKey("sys_user.id"))
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    __table_args__ = (UniqueConstraint("post_id", "user_id", name="uq_disc_like"),)


class DiscussionReplyLike(Base):
    """讨论回复点赞记录（一人一回复一次，幂等）。"""
    __tablename__ = "discussion_reply_like"

    id: Mapped[int] = mapped_column(primary_key=True)
    reply_id: Mapped[int] = mapped_column(ForeignKey("discussion_reply.id"))
    user_id: Mapped[int] = mapped_column(ForeignKey("sys_user.id"))
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    __table_args__ = (UniqueConstraint("reply_id", "user_id", name="uq_disc_reply_like"),)


__all__ = [
    "Notification", "NotificationRead", "SignTask", "SignRecord",
    "DiscussionPost", "DiscussionReply", "DiscussionLike", "DiscussionReplyLike",
]
