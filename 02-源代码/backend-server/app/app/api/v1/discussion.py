from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth import current_user, get_optional_user, require_roles
from app.core.response import success
from app.database import get_db
from app.models import DiscussionPost, DiscussionReply, DiscussionLike, DiscussionReplyLike, SensitiveWord, User
from app.schemas import DiscussionCreate, ReplyCreate, ReportCreate
from app.services.sensitive import scan_sensitive

router = APIRouter()


async def _sensitive_words(db: AsyncSession) -> list[str]:
    rows = (await db.execute(select(SensitiveWord.word))).scalars().all()
    return list(rows)


def _user_brief(u: User) -> dict:
    return {
        "id": u.id,
        "username": u.username,
        "real_name": u.real_name or "",
        "user_code": u.user_code or "",
        "role": u.role,
    }


@router.get("/discussions", tags=["discussion"])
async def list_discussions(
    course_id: int | None = None,
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),  # 需求 16：10/50/100 条分页
    db: AsyncSession = Depends(get_db),
    user=Depends(get_optional_user),
):
    # 广场/课程讨论均排除教师教研区（course_id=0，需求 9：学生不可见）
    statement = select(DiscussionPost).where(
        DiscussionPost.course_id != 0,
        DiscussionPost.review_status == 1,
        DiscussionPost.status == 1,
    )
    if course_id is not None:
        statement = statement.where(DiscussionPost.course_id == course_id)
    total = len((await db.execute(statement)).scalars().all())
    posts = (
        await db.execute(
            statement.order_by(DiscussionPost.is_pinned.desc(), DiscussionPost.created_at.desc())
            .offset((page - 1) * page_size)
            .limit(page_size)
        )
    ).scalars().all()
    liked_set: set[int] = set()
    if user is not None and posts:
        post_ids = [p.id for p in posts]
        liked_rows = (
            await db.execute(
                select(DiscussionLike.post_id).where(DiscussionLike.post_id.in_(post_ids), DiscussionLike.user_id == user.id)
            )
        ).scalars().all()
        liked_set = set(liked_rows)
    # 作者信息批量查询（需求 6：讨论区显示用户 id 与用户名）
    author_ids = list({p.user_id for p in posts})
    authors: dict[int, User] = {}
    if author_ids:
        rows = (await db.execute(select(User).where(User.id.in_(author_ids)))).scalars().all()
        authors = {u.id: u for u in rows}
    return success({
        "page": page,
        "page_size": page_size,
        "total": total,
        "items": [
            {
                "id": p.id,
                "course_id": p.course_id,
                "user_id": p.user_id,
                "author": _user_brief(authors[p.user_id]) if p.user_id in authors else None,
                "title": p.title,
                "content": p.content,
                "is_pinned": p.is_pinned,
                "like_count": p.like_count,
                "reply_count": len(
                    (await db.execute(
                        select(DiscussionReply.id).where(
                            DiscussionReply.post_id == p.id, DiscussionReply.review_status == 1
                        )
                    )).scalars().all()
                ),
                "liked_by_me": p.id in liked_set,
                "created_at": p.created_at,
            }
            for p in posts
        ],
    })


@router.post("/discussions", tags=["discussion"])
async def create_discussion(payload: DiscussionCreate, db: AsyncSession = Depends(get_db), user=Depends(current_user)):
    words = await _sensitive_words(db)
    hits = scan_sensitive(f"{payload.title or ''}\n{payload.content}", words)
    post = DiscussionPost(
        course_id=payload.course_id,
        user_id=user.id,
        title=payload.title,
        content=payload.content,
        review_status=0 if hits else 1,
    )
    db.add(post)
    await db.commit()
    await db.refresh(post)
    return success({
        "id": post.id,
        "course_id": post.course_id,
        "title": post.title,
        "content": post.content,
        "review_status": post.review_status,
        "sensitive_hits": hits,
    })


@router.post("/discussions/{post_id}/replies", tags=["discussion"])
async def create_reply(post_id: int, payload: ReplyCreate, db: AsyncSession = Depends(get_db), user=Depends(current_user)):
    post = await db.get(DiscussionPost, post_id)
    if not post or post.status != 1:
        raise HTTPException(404, "帖子不存在")
    words = await _sensitive_words(db)
    hits = scan_sensitive(payload.content, words)
    reply = DiscussionReply(
        post_id=post_id,
        user_id=user.id,
        content=payload.content,
        reply_to_id=payload.reply_to_id,
        review_status=0 if hits else 1,
    )
    db.add(reply)
    await db.commit()
    await db.refresh(reply)
    return success({"id": reply.id, "post_id": reply.post_id, "content": reply.content, "review_status": reply.review_status})


@router.post("/discussions/{post_id}/like", tags=["discussion"])
async def like_discussion(post_id: int, db: AsyncSession = Depends(get_db), user=Depends(current_user)):
    """点赞（一人一次，幂等：重复点赞返回当前计数并提示已赞过）。"""
    post = await db.get(DiscussionPost, post_id)
    if not post or post.status != 1:
        raise HTTPException(404, "帖子不存在")
    existing = (await db.execute(
        select(DiscussionLike).where(DiscussionLike.post_id == post_id, DiscussionLike.user_id == user.id)
    )).scalar_one_or_none()
    if existing is None:
        db.add(DiscussionLike(post_id=post_id, user_id=user.id))
        post.like_count = (post.like_count or 0) + 1
        await db.commit()
        return success({"id": post.id, "like_count": post.like_count, "liked_by_me": True, "first_time": True})
    # 已点过：幂等返回
    return success({"id": post.id, "like_count": post.like_count or 0, "liked_by_me": True, "first_time": False})


@router.delete("/discussions/{post_id}", tags=["discussion"])
async def delete_discussion(post_id: int, db: AsyncSession = Depends(get_db), user=Depends(require_roles("TEACHER", "ADMIN"))):
    post = await db.get(DiscussionPost, post_id)
    if not post:
        raise HTTPException(404, "帖子不存在")
    post.status = 0
    await db.commit()
    return success({"id": post_id, "deleted": True})


# ═══ 需求 9：教师教学讨论区（TEACHER/ADMIN 专属，学生 403）═══
@router.get("/discussions/teacher-room", tags=["discussion"])
async def teacher_room(db: AsyncSession = Depends(get_db), user=Depends(require_roles("TEACHER", "ADMIN"))):
    posts = (
        await db.execute(
            select(DiscussionPost)
            .where(DiscussionPost.course_id == 0, DiscussionPost.review_status == 1, DiscussionPost.status == 1)
            .order_by(DiscussionPost.created_at.desc())
            .limit(100)
        )
    ).scalars().all()
    uids = list({p.user_id for p in posts})
    users: dict[int, User] = {}
    if uids:
        rows = (await db.execute(select(User).where(User.id.in_(uids)))).scalars().all()
        users = {u.id: u for u in rows}
    liked: set[int] = set()
    if posts:
        rows = (
            await db.execute(
                select(DiscussionLike.post_id).where(
                    DiscussionLike.post_id.in_([p.id for p in posts]), DiscussionLike.user_id == user.id
                )
            )
        ).scalars().all()
        liked = set(rows)
    return success([
        {
            "id": p.id,
            "course_id": p.course_id,
            "user_id": p.user_id,
            "author": _user_brief(users[p.user_id]) if p.user_id in users else None,
            "title": p.title,
            "content": p.content,
            "like_count": p.like_count,
            "liked_by_me": p.id in liked,
            "created_at": p.created_at,
        }
        for p in posts
    ])


@router.post("/discussions/teacher-room", tags=["discussion"])
async def create_teacher_room_post(
    payload: dict, db: AsyncSession = Depends(get_db), user=Depends(require_roles("TEACHER", "ADMIN"))
):
    """教学讨论区发帖：只取 title/content，course_id 固定 0（教师专属空间）。"""
    title = str(payload.get("title") or "")
    content = str(payload.get("content") or "").strip()
    if not content:
        raise HTTPException(422, "内容不能为空")
    words = await _sensitive_words(db)
    hits = scan_sensitive(f"{title}\n{content}", words)
    post = DiscussionPost(
        course_id=0,  # 0 = 教师休息室（特殊空间）
        user_id=user.id,
        title=title,
        content=content,
        review_status=0 if hits else 1,
    )
    db.add(post)
    await db.commit()
    await db.refresh(post)
    return success({"id": post.id, "course_id": 0, "title": post.title, "sensitive_hits": hits})


# ═══ 需求 6/16：帖子详情（回复列表 + 作者信息 + 回复点赞状态）═══
@router.get("/discussions/{post_id}", tags=["discussion"])
async def discussion_detail(post_id: int, db: AsyncSession = Depends(get_db), user=Depends(get_optional_user)):
    post = await db.get(DiscussionPost, post_id)
    if not post or post.status != 1:
        raise HTTPException(404, "帖子不存在")
    replies = (
        await db.execute(
            select(DiscussionReply)
            .where(DiscussionReply.post_id == post_id, DiscussionReply.review_status == 1)
            .order_by(DiscussionReply.created_at.asc())
        )
    ).scalars().all()
    # 作者与回复者信息
    uids = list({post.user_id} | {r.user_id for r in replies})
    users: dict[int, User] = {}
    if uids:
        rows = (await db.execute(select(User).where(User.id.in_(uids)))).scalars().all()
        users = {u.id: u for u in rows}
    # 我点过赞的回复集合（帖子点赞沿用 like 接口的 liked_by_me）
    liked_replies: set[int] = set()
    if user is not None and replies:
        reply_ids = [r.id for r in replies]
        rows = (
            await db.execute(
                select(DiscussionReplyLike.reply_id).where(
                    DiscussionReplyLike.reply_id.in_(reply_ids), DiscussionReplyLike.user_id == user.id
                )
            )
        ).scalars().all()
        liked_replies = set(rows)
    liked_post = False
    if user is not None:
        liked_post = (
            await db.execute(
                select(DiscussionLike).where(
                    DiscussionLike.post_id == post_id, DiscussionLike.user_id == user.id
                )
            )
        ).scalar_one_or_none() is not None
    return success({
        "id": post.id,
        "course_id": post.course_id,
        "user_id": post.user_id,
        "author": _user_brief(users[post.user_id]) if post.user_id in users else None,
        "title": post.title,
        "content": post.content,
        "is_pinned": post.is_pinned,
        "like_count": post.like_count,
        "liked_by_me": liked_post,
        "created_at": post.created_at,
        "replies": [
            {
                "id": r.id,
                "post_id": r.post_id,
                "user_id": r.user_id,
                "author": _user_brief(users[r.user_id]) if r.user_id in users else None,
                "content": r.content,
                "reply_to_id": r.reply_to_id,
                "like_count": r.like_count,
                "liked_by_me": r.id in liked_replies,
                "created_at": r.created_at,
            }
            for r in replies
        ],
    })


# ═══ 需求 6：回复点赞（一人一次，幂等）═══
@router.post("/discussions/replies/{reply_id}/like", tags=["discussion"])
async def like_reply(reply_id: int, db: AsyncSession = Depends(get_db), user=Depends(current_user)):
    reply = await db.get(DiscussionReply, reply_id)
    if not reply or reply.review_status != 1:
        raise HTTPException(404, "回复不存在")
    existing = (
        await db.execute(
            select(DiscussionReplyLike).where(
                DiscussionReplyLike.reply_id == reply_id, DiscussionReplyLike.user_id == user.id
            )
        )
    ).scalar_one_or_none()
    if existing is None:
        db.add(DiscussionReplyLike(reply_id=reply_id, user_id=user.id))
        reply.like_count = (reply.like_count or 0) + 1
        await db.commit()
        return success({"id": reply.id, "like_count": reply.like_count, "liked_by_me": True, "first_time": True})
    return success({"id": reply.id, "like_count": reply.like_count or 0, "liked_by_me": True, "first_time": False})


@router.post("/reports", tags=["discussion"])
async def report_content(payload: ReportCreate, db: AsyncSession = Depends(get_db), user=Depends(current_user)):
    target_type = payload.target_type.upper()
    if target_type == "POST":
        obj = await db.get(DiscussionPost, payload.target_id)
    elif target_type == "REPLY":
        obj = await db.get(DiscussionReply, payload.target_id)
    else:
        raise HTTPException(422, "target_type 必须是 POST 或 REPLY")
    if not obj:
        raise HTTPException(404, "举报对象不存在")
    obj.review_status = 0
    await db.commit()
    return success({"target_type": target_type, "target_id": payload.target_id, "review_status": 0})
