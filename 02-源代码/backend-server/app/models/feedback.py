from __future__ import annotations

from datetime import datetime

from sqlalchemy import Integer, String, Text, DateTime, ForeignKey
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


class Feedback(Base):
    """用户反馈中心：学生/教师提交，管理端处理。需求 18。"""

    __tablename__ = "feedback"

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("sys_user.id"))
    # 分类：BUG 缺陷 / FEATURE 功能建议 / EXPERIENCE 体验问题 / CONTENT 内容纠错 / OTHER 其他
    category: Mapped[str] = mapped_column(String(20), default="OTHER")
    title: Mapped[str] = mapped_column(String(120))
    content: Mapped[str] = mapped_column(Text)
    # 联系方式（可选，便于回访）
    contact: Mapped[str | None] = mapped_column(String(100), nullable=True)
    # 截图/附件 URL（可选）
    attachment_url: Mapped[str | None] = mapped_column(String(300), nullable=True)
    # 状态：PENDING 待处理 / PROCESSING 处理中 / RESOLVED 已解决 / REJECTED 已驳回
    status: Mapped[str] = mapped_column(String(20), default="PENDING")
    # 管理员处理结果（可选）
    reply: Mapped[str | None] = mapped_column(Text, nullable=True)
    handled_by: Mapped[int | None] = mapped_column(ForeignKey("sys_user.id"), nullable=True)
    handled_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
