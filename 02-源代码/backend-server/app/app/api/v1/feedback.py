from __future__ import annotations

from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth import current_user, require_roles
from app.core.response import success
from app.database import get_db
from app.models import Feedback, User

router = APIRouter()

CATEGORIES = {"BUG", "FEATURE", "EXPERIENCE", "CONTENT", "OTHER"}
STATUSES = {"PENDING", "PROCESSING", "RESOLVED", "REJECTED"}

CATEGORY_LABELS = {
    "BUG": "缺陷反馈", "FEATURE": "功能建议", "EXPERIENCE": "体验问题",
    "CONTENT": "内容纠错", "OTHER": "其他",
}
STATUS_LABELS = {"PENDING": "待处理", "PROCESSING": "处理中", "RESOLVED": "已解决", "REJECTED": "已驳回"}


class FeedbackCreate(BaseModel):
    category: str = Field(default="OTHER", max_length=20)
    title: str = Field(min_length=2, max_length=120)
    content: str = Field(min_length=5)
    contact: str | None = Field(default=None, max_length=100)


class FeedbackHandle(BaseModel):
    status: str
    reply: str | None = Field(default=None, max_length=2000)


def _brief(f: Feedback, submitter: User | None, handler: User | None) -> dict:
    return {
        "id": f.id,
        "user_id": f.user_id,
        "username": submitter.username if submitter else "",
        "real_name": submitter.real_name if submitter else "",
        "role": submitter.role if submitter else "",
        "category": f.category,
        "category_label": CATEGORY_LABELS.get(f.category, f.category),
        "title": f.title,
        "content": f.content,
        "contact": f.contact,
        "status": f.status,
        "status_label": STATUS_LABELS.get(f.status, f.status),
        "reply": f.reply,
        "handled_by": f.handled_by,
        "handler_name": handler.real_name if handler else None,
        "handled_at": f.handled_at.strftime("%Y-%m-%d %H:%M:%S") if f.handled_at else None,
        "created_at": f.created_at.strftime("%Y-%m-%d %H:%M:%S") if f.created_at else None,
    }


@router.get("/feedback/my", tags=["feedback"])
async def my_feedback(db: AsyncSession = Depends(get_db), user=Depends(current_user)):
    """学生/教师查看自己提交的反馈列表（含处理进度）。"""
    rows = (
        await db.execute(
            select(Feedback).where(Feedback.user_id == user.id).order_by(Feedback.created_at.desc())
        )
    ).scalars().all()
    return success([_brief(f, user, None) for f in rows])


@router.post("/feedback", tags=["feedback"])
async def create_feedback(
    payload: FeedbackCreate,
    db: AsyncSession = Depends(get_db),
    user=Depends(require_roles("STUDENT", "TEACHER")),
):
    """提交反馈（学生/教师）。"""
    if payload.category not in CATEGORIES:
        raise HTTPException(status_code=400, detail="无效的反馈分类")
    f = Feedback(
        user_id=user.id,
        category=payload.category,
        title=payload.title.strip(),
        content=payload.content.strip(),
        contact=(payload.contact or "").strip() or None,
        status="PENDING",
    )
    db.add(f)
    await db.commit()
    await db.refresh(f)
    return success({"id": f.id, "message": "反馈已提交，我们会尽快处理"})


@router.get("/admin/feedback", tags=["feedback"])
async def admin_list_feedback(
    status: str | None = None,
    category: str | None = None,
    page: int = 1,
    page_size: int = 20,
    db: AsyncSession = Depends(get_db),
    user=Depends(require_roles("ADMIN")),
):
    """管理端反馈列表：按状态/分类筛选 + 分页。"""
    stmt = select(Feedback)
    if status:
        stmt = stmt.where(Feedback.status == status)
    if category:
        stmt = stmt.where(Feedback.category == category)
    total = (await db.execute(select(func.count()).select_from(stmt.subquery()))).scalar() or 0
    rows = (
        await db.execute(
            stmt.order_by(Feedback.status == "PENDING", Feedback.created_at.desc())
            .offset((page - 1) * page_size)
            .limit(page_size)
        )
    ).scalars().all()

    uids = list({f.user_id for f in rows} | {f.handled_by for f in rows if f.handled_by})
    users: dict[int, User] = {}
    if uids:
        found = (await db.execute(select(User).where(User.id.in_(uids)))).scalars().all()
        users = {u.id: u for u in found}
    return success({
        "total": total,
        "page": page,
        "page_size": page_size,
        "items": [_brief(f, users.get(f.user_id), users.get(f.handled_by)) for f in rows],
    })


@router.put("/admin/feedback/{feedback_id}", tags=["feedback"])
async def handle_feedback(
    feedback_id: int,
    payload: FeedbackHandle,
    db: AsyncSession = Depends(get_db),
    user=Depends(require_roles("ADMIN")),
):
    """管理端处理反馈：更新状态 + 回复。"""
    f = (await db.execute(select(Feedback).where(Feedback.id == feedback_id))).scalar()
    if f is None:
        raise HTTPException(status_code=404, detail="反馈不存在")
    if payload.status not in STATUSES:
        raise HTTPException(status_code=400, detail="无效的状态")
    f.status = payload.status
    if payload.reply:
        f.reply = payload.reply.strip()
    f.handled_by = user.id
    f.handled_at = datetime.utcnow()
    await db.commit()
    await db.refresh(f)
    return success(_brief(f, None, user))


@router.get("/admin/feedback/stats", tags=["feedback"])
async def feedback_stats(db: AsyncSession = Depends(get_db), user=Depends(require_roles("ADMIN"))):
    """管理端反馈统计：各状态数量。"""
    rows = (
        await db.execute(select(Feedback.status, func.count()).group_by(Feedback.status))
    ).all()
    by_status = {s: c for s, c in rows}
    return success({
        "total": sum(by_status.values()),
        "pending": by_status.get("PENDING", 0),
        "processing": by_status.get("PROCESSING", 0),
        "resolved": by_status.get("RESOLVED", 0),
        "rejected": by_status.get("REJECTED", 0),
    })
