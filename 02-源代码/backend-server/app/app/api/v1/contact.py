"""联系人域：唯一用户号 / 好友 / 我的老师 / 私聊 / 备注。

设计要点：
- 用户号 user_code：全库唯一，注册自动分配（SL + 6 位数字），可在「搜索用户号」页精确查人。
- 好友（FRIEND）与师生（TEACHER）共用 friendship 表，靠 rel_type 区分；申请-同意流一致。
- 申请/同意产生 Notification（type=FRIEND_REQUEST / FRIEND_ACCEPT / TEACHER_LINK），前端消息页展示并跳转。
- 同一课程的学生-教师（选课关系成立时）自动建立 TEACHER-ACCEPTED 关系（幂等）。
- 私聊 chat_message：发送（需存在 ACCEPTED 关系）→ 会话列表（每人最新一条+未读数）→ 历史消息（分页）→ 已读。
- 备注 remark：每人每关系一份，仅作用于自己看对方的名字。
"""
from __future__ import annotations

from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy import select, func, or_, and_, distinct
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth import current_user
from app.core.response import success
from app.database import get_db
from app.models import ChatMessage, Course, CourseEnrollment, Friendship, Notification, User

router = APIRouter()


def _gen_user_code(user_id: int) -> str:
    """稳定用户号：SL + 用户 id 左补零到 6 位（保证唯一、可读）。"""
    return f"SL{user_id:06d}"


def _notify(db: AsyncSession, *, type_: str, title: str, content: str, target_role: str, sender_id: int | None):
    n = Notification(type=type_, title=title, content=content, sender_id=sender_id, target_role=target_role)
    db.add(n)


def _user_brief(u: User) -> dict:
    return {
        "id": u.id, "username": u.username, "real_name": u.real_name or "",
        "role": u.role, "user_code": u.user_code or _gen_user_code(u.id),
        "avatar": u.avatar_url or "",
    }


# ─────────────────────── 用户号查询 ───────────────────────

@router.get("/contacts/search", tags=["contacts"])
async def search_by_code(code: str, db: AsyncSession = Depends(get_db), user=Depends(current_user)):
    """按唯一用户号精确搜索用户（加好友/加老师入口）。"""
    code = (code or "").strip()
    if not code:
        raise HTTPException(422, "请输入用户号")
    target = (
        await db.execute(select(User).where(User.user_code == code, User.deleted_at.is_(None)))
    ).scalar_one_or_none()
    if not target:
        raise HTTPException(404, "未找到该用户号对应的用户")
    if target.id == user.id:
        raise HTTPException(400, "不能添加自己")
    # 现有关系回显
    rel = await db.scalar(select(Friendship).where(
        or_(
            and_(Friendship.requester_id == user.id, Friendship.addressee_id == target.id),
            and_(Friendship.requester_id == target.id, Friendship.addressee_id == user.id),
        )
    ))
    return success({
        "user": _user_brief(target),
        "existing": (
            {"rel_type": rel.rel_type, "status": rel.status, "direction": "outgoing" if rel.requester_id == user.id else "incoming"}
            if rel else None
        ),
    })


# ─────────────────────── 申请 / 同意 ───────────────────────

class ApplyRequest(BaseModel):
    user_code: str = Field(min_length=3, max_length=12)
    rel_type: str = Field(default="FRIEND", pattern="^(FRIEND|TEACHER)$")


@router.post("/contacts/apply", tags=["contacts"])
async def apply_contact(payload: ApplyRequest, db: AsyncSession = Depends(get_db), user=Depends(current_user)):
    """发起好友/老师申请。TEACHER 类型仅学生→教师方向。"""
    target = (
        await db.execute(select(User).where(User.user_code == payload.user_code, User.deleted_at.is_(None)))
    ).scalar_one_or_none()
    if not target:
        raise HTTPException(404, "用户不存在")
    if target.id == user.id:
        raise HTTPException(400, "不能添加自己")
    if payload.rel_type == "TEACHER" and not (user.role == "STUDENT" and target.role == "TEACHER"):
        raise HTTPException(400, "「我的老师」仅支持学生关联教师")
    # 反向或正向已有记录？
    rel = await db.scalar(select(Friendship).where(
        or_(
            and_(Friendship.requester_id == user.id, Friendship.addressee_id == target.id),
            and_(Friendship.requester_id == target.id, Friendship.addressee_id == user.id),
        ),
        Friendship.rel_type == payload.rel_type,
    ))
    if rel:
        if rel.status == "ACCEPTED":
            return success({"already": True, "status": "ACCEPTED", "message": "你们已是好友/已关联"})
        if rel.status == "PENDING":
            return success({"already": True, "status": "PENDING", "message": "申请处理中"})
        rel.status = "PENDING"
        rel.requester_id, rel.addressee_id = user.id, target.id
    else:
        rel = Friendship(requester_id=user.id, addressee_id=target.id, rel_type=payload.rel_type, status="PENDING")
        db.add(rel)
    _notify(
        db,
        type_="FRIEND_REQUEST" if payload.rel_type == "FRIEND" else "TEACHER_LINK",
        title=f"{user.real_name or user.username} 请求添加你为{'好友' if payload.rel_type == 'FRIEND' else '学生'}",
        content=f"用户号 {user.user_code}，请在消息页处理。",
        target_role=target.role,
        sender_id=user.id,
    )
    await db.commit()
    return success({"already": False, "status": "PENDING", "message": "申请已发送，等待对方同意"})


class HandleRequest(BaseModel):
    requester_id: int
    rel_type: str = Field(default="FRIEND", pattern="^(FRIEND|TEACHER)$")
    accept: bool


@router.post("/contacts/handle", tags=["contacts"])
async def handle_contact(payload: HandleRequest, db: AsyncSession = Depends(get_db), user=Depends(current_user)):
    """同意/拒绝申请。同意后双向生效，互发通知。"""
    rel = await db.scalar(select(Friendship).where(
        Friendship.requester_id == payload.requester_id, Friendship.addressee_id == user.id,
        Friendship.rel_type == payload.rel_type,
    ))
    if not rel:
        raise HTTPException(404, "没有该申请")
    if rel.status != "PENDING":
        raise HTTPException(409, f"该申请已处理（{rel.status}）")
    rel.status = "ACCEPTED" if payload.accept else "REJECTED"
    requester = await db.get(User, payload.requester_id)
    if payload.accept and requester:
        _notify(
            db,
            type_="FRIEND_ACCEPT",
            title=f"{user.real_name or user.username} 已同意你的{'好友' if payload.rel_type == 'FRIEND' else '关联'}申请",
            content="现在可以开始聊天了。",
            target_role=requester.role,
            sender_id=user.id,
        )
    await db.commit()
    return success({"status": rel.status, "requester_id": payload.requester_id})


# ─────────────────────── 列表 ───────────────────────

async def _enriched_contacts(db: AsyncSession, me: User, rel_type: str) -> list[dict]:
    """返回我方 ACCEPTED 关系列表（好友或老师），带备注/最后一条消息/未读数。"""
    rels = (
        await db.execute(
            select(Friendship).where(
                or_(Friendship.requester_id == me.id, Friendship.addressee_id == me.id),
                Friendship.rel_type == rel_type, Friendship.status == "ACCEPTED",
            )
        )
    ).scalars().all()
    out = []
    for rel in rels:
        other_id = rel.addressee_id if rel.requester_id == me.id else rel.requester_id
        other = await db.get(User, other_id)
        if not other or other.deleted_at is not None:
            continue
        my_remark = rel.remark if rel.requester_id == me.id else None
        # 对方对我的备注不返回（隐私）
        if rel.requester_id != me.id:
            my_remark = await db.scalar(select(Friendship.remark).where(
                Friendship.requester_id == me.id, Friendship.addressee_id == other_id, Friendship.rel_type == rel_type,
            ))
        last = (
            await db.execute(
                select(ChatMessage).where(
                    or_(
                        and_(ChatMessage.sender_id == me.id, ChatMessage.receiver_id == other_id),
                        and_(ChatMessage.sender_id == other_id, ChatMessage.receiver_id == me.id),
                    )
                ).order_by(ChatMessage.id.desc()).limit(1)
            )
        ).scalar_one_or_none()
        unread = await db.scalar(select(func.count(ChatMessage.id)).where(
            ChatMessage.sender_id == other_id, ChatMessage.receiver_id == me.id, ChatMessage.is_read == 0,
        ))
        out.append({
            "user": _user_brief(other),
            "remark": my_remark,
            "display_name": my_remark or (other.real_name or other.username),
            "last_message": last.content if last else "",
            "last_at": last.created_at if last else None,
            "unread": unread or 0,
        })
    out.sort(key=lambda x: (x["last_at"] is None, x["last_at"]), reverse=False)
    out.sort(key=lambda x: x["last_at"] is not None and str(x["last_at"]) or "", reverse=True)
    return out


@router.get("/contacts/friends", tags=["contacts"])
async def my_friends(db: AsyncSession = Depends(get_db), user=Depends(current_user)):
    return success(await _enriched_contacts(db, user, "FRIEND"))


@router.get("/contacts/teachers", tags=["contacts"])
async def my_teachers(db: AsyncSession = Depends(get_db), user=Depends(current_user)):
    return success(await _enriched_contacts(db, user, "TEACHER"))


@router.get("/contacts/requests/incoming", tags=["contacts"])
async def incoming_requests(db: AsyncSession = Depends(get_db), user=Depends(current_user)):
    """收到的待处理申请（消息页展示）。"""
    rels = (
        await db.execute(
            select(Friendship).where(Friendship.addressee_id == user.id, Friendship.status == "PENDING")
        )
    ).scalars().all()
    out = []
    for rel in rels:
        requester = await db.get(User, rel.requester_id)
        if requester:
            out.append({
                "requester": _user_brief(requester),
                "rel_type": rel.rel_type,
                "created_at": rel.created_at,
            })
    return success(out)


# ─────────────────────── 备注 ───────────────────────

class RemarkUpdate(BaseModel):
    target_id: int
    rel_type: str = Field(default="FRIEND", pattern="^(FRIEND|TEACHER)$")
    remark: str = Field(default="", max_length=50)


@router.put("/contacts/remark", tags=["contacts"])
async def update_remark(payload: RemarkUpdate, db: AsyncSession = Depends(get_db), user=Depends(current_user)):
    """编辑我对某联系人的备注名。若我是 addressee 方，反向建立一条 ACCEPTED 同型关系承载备注（幂等）。"""
    rel = await db.scalar(select(Friendship).where(
        Friendship.requester_id == user.id, Friendship.addressee_id == payload.target_id, Friendship.rel_type == payload.rel_type,
    ))
    if rel:
        rel.remark = payload.remark or None
    else:
        # 我是接收方：确认存在对方→我的关系
        reverse = await db.scalar(select(Friendship).where(
            Friendship.requester_id == payload.target_id, Friendship.addressee_id == user.id, Friendship.rel_type == payload.rel_type,
        ))
        if not reverse:
            raise HTTPException(404, "关系不存在")
        rel = Friendship(requester_id=user.id, addressee_id=payload.target_id,
                         rel_type=payload.rel_type, status="ACCEPTED", remark=payload.remark or None)
        db.add(rel)
    await db.commit()
    return success({"target_id": payload.target_id, "remark": rel.remark})


# ─────────────────────── 私聊 ───────────────────────

class MessageSend(BaseModel):
    receiver_id: int
    content: str = Field(min_length=1, max_length=2000)


async def _ensure_related(db: AsyncSession, me_id: int, other_id: int) -> None:
    rel = await db.scalar(select(Friendship).where(
        or_(
            and_(Friendship.requester_id == me_id, Friendship.addressee_id == other_id),
            and_(Friendship.requester_id == other_id, Friendship.addressee_id == me_id),
        ),
        Friendship.status == "ACCEPTED",
    ))
    if not rel:
        raise HTTPException(403, "你们还不是好友/未建立关联，无法发送消息")


@router.post("/chat/send", tags=["chat"])
async def send_message(payload: MessageSend, db: AsyncSession = Depends(get_db), user=Depends(current_user)):
    if payload.receiver_id == user.id:
        raise HTTPException(400, "不能给自己发消息")
    await _ensure_related(db, user.id, payload.receiver_id)
    msg = ChatMessage(sender_id=user.id, receiver_id=payload.receiver_id, content=payload.content)
    db.add(msg)
    await db.commit()
    await db.refresh(msg)
    return success({"id": msg.id, "sender_id": msg.sender_id, "receiver_id": msg.receiver_id,
                   "content": msg.content, "created_at": msg.created_at, "is_read": 0})


@router.get("/chat/history/{other_id}", tags=["chat"])
async def chat_history(other_id: int, before_id: int = 0, limit: int = 50,
                       db: AsyncSession = Depends(get_db), user=Depends(current_user)):
    """与某人的消息历史（时间升序返回），before_id 分页。进入时未读全部置已读。"""
    await db.execute(
        ChatMessage.__table__.update().where(
            and_(ChatMessage.sender_id == other_id, ChatMessage.receiver_id == user.id, ChatMessage.is_read == 0)
        ).values(is_read=1)
    )
    await db.commit()
    stmt = select(ChatMessage).where(
        or_(
            and_(ChatMessage.sender_id == user.id, ChatMessage.receiver_id == other_id),
            and_(ChatMessage.sender_id == other_id, ChatMessage.receiver_id == user.id),
        )
    ).order_by(ChatMessage.id.desc()).limit(min(limit, 100))
    if before_id:
        stmt = stmt.where(ChatMessage.id < before_id)
    rows = (await db.execute(stmt)).scalars().all()
    rows.reverse()
    return success([
        {"id": m.id, "sender_id": m.sender_id, "receiver_id": m.receiver_id,
         "content": m.content, "is_read": m.is_read, "created_at": m.created_at}
        for m in rows
    ])


@router.get("/chat/unread-count", tags=["chat"])
async def chat_unread(db: AsyncSession = Depends(get_db), user=Depends(current_user)):
    n = await db.scalar(select(func.count(ChatMessage.id)).where(
        ChatMessage.receiver_id == user.id, ChatMessage.is_read == 0,
    ))
    return success({"unread": n or 0})


# ─────────────────────── 同课自动关联 ───────────────────────

async def auto_link_course_contacts(db: AsyncSession, course_id: int) -> int:
    """某课程的学生↔授课教师自动建立 TEACHER-ACCEPTED（幂等，供选课/建课调用）。"""
    course = await db.get(Course, course_id)
    if not course or not course.teacher_id:
        return 0
    student_ids = (
        await db.execute(select(CourseEnrollment.user_id).where(CourseEnrollment.course_id == course_id))
    ).scalars().all()
    linked = 0
    for sid in student_ids:
        if sid == course.teacher_id:
            continue
        exists = await db.scalar(select(Friendship).where(
            or_(
                and_(Friendship.requester_id == sid, Friendship.addressee_id == course.teacher_id),
                and_(Friendship.requester_id == course.teacher_id, Friendship.addressee_id == sid),
            ),
            Friendship.rel_type == "TEACHER",
        ))
        if not exists:
            db.add(Friendship(requester_id=sid, addressee_id=course.teacher_id,
                              rel_type="TEACHER", status="ACCEPTED"))
            linked += 1
    if linked:
        await db.commit()
    return linked
