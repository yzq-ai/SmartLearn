from __future__ import annotations

from datetime import datetime

from sqlalchemy import Integer, String, Text, DateTime, ForeignKey, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


class Friendship(Base):
    """联系人关系：好友（互加，双方均需为 STUDENT/TEACHER 任意角色）或师生（老师关联）。

    - type=FRIEND：学生/教师之间互加好友。
    - type=TEACHER：学生-教师关联（同课自动建立或用户码手动申请）。
    - requester 发起申请 → addressee 同意（status ACCEPTED）后建立关系。
    - remark：requester 对 addressee 的备注名（每人每关系一份）。
    - 同一对用户 FRIEND 与 TEACHER 各可存在一条（ requester 方向为准，约定小 id 为 requester 防重复反向）。
    """

    __tablename__ = "friendship"
    id: Mapped[int] = mapped_column(primary_key=True)
    requester_id: Mapped[int] = mapped_column(ForeignKey("sys_user.id"), index=True)
    addressee_id: Mapped[int] = mapped_column(ForeignKey("sys_user.id"), index=True)
    rel_type: Mapped[str] = mapped_column(String(10), default="FRIEND")  # FRIEND / TEACHER
    status: Mapped[str] = mapped_column(String(10), default="PENDING")  # PENDING / ACCEPTED / REJECTED
    remark: Mapped[str | None] = mapped_column(String(50), nullable=True)  # requester 对 addressee 的备注
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    __table_args__ = (
        UniqueConstraint("requester_id", "addressee_id", "rel_type", name="uq_friend_pair"),
    )


class ChatMessage(Base):
    """私聊消息：任意两用户（好友或师生关系成立后可发）。"""

    __tablename__ = "chat_message"
    id: Mapped[int] = mapped_column(primary_key=True)
    sender_id: Mapped[int] = mapped_column(ForeignKey("sys_user.id"), index=True)
    receiver_id: Mapped[int] = mapped_column(ForeignKey("sys_user.id"), index=True)
    content: Mapped[str] = mapped_column(Text)
    is_read: Mapped[int] = mapped_column(Integer, default=0)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)


__all__ = ["Friendship", "ChatMessage"]
