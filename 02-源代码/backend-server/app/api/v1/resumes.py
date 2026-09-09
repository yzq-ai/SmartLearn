from __future__ import annotations

import json

from fastapi import APIRouter, Depends, HTTPException
from fastapi.responses import Response
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth import current_user
from app.core.response import success
from app.database import get_db
from app.models import Resume
from app.schemas import ResumeCreate

router = APIRouter()


@router.get("/resumes", tags=["resumes"])
async def list_resumes(db: AsyncSession = Depends(get_db), user=Depends(current_user)):
    rows = (await db.execute(select(Resume).where(Resume.user_id == user.id).order_by(Resume.updated_at.desc()))).scalars().all()
    return success([
        {"id": r.id, "title": r.title, "content": r.content, "version": r.version, "is_default": r.is_default}
        for r in rows
    ])


@router.post("/resumes", tags=["resumes"])
async def create_resume(payload: ResumeCreate, db: AsyncSession = Depends(get_db), user=Depends(current_user)):
    resume = Resume(user_id=user.id, title=payload.title, content=payload.content, version=1, is_default=1)
    db.add(resume)
    await db.commit()
    await db.refresh(resume)
    return success({"id": resume.id, "title": resume.title, "content": resume.content, "version": resume.version})


@router.get("/resumes/{resume_id}/pdf", tags=["resumes"])
async def export_resume_pdf(resume_id: int, db: AsyncSession = Depends(get_db), user=Depends(current_user)):
    """导出简历 PDF（reportlab 真实 PDF，中文 STSong-Light）。"""
    from app.utils.pdf import build_resume_pdf

    resume = (await db.execute(select(Resume).where(Resume.id == resume_id))).scalar_one_or_none()
    if not resume or resume.user_id != user.id:
        raise HTTPException(status_code=404, detail="简历不存在")

    c = resume.content or {}

    def _sec(zh: str, en: str) -> str:
        """兼容中文字段（seed 数据）与英文字段（部分历史数据）。"""
        v = c.get(zh) or c.get(en) or ""
        return v if isinstance(v, str) else json.dumps(v, ensure_ascii=False)

    name = (resume.title or "").replace("的求职简历", "").strip() or user.real_name or ""
    sections = [
        ("基本信息", f"姓名：{name}" if name else ""),
        ("教育背景", _sec("教育背景", "education")),
        ("技能清单", _sec("技能清单", "skills")),
        ("项目经历", _sec("项目经历", "projects")),
        ("校园经历", _sec("校园经历", "internships")),
        ("获奖情况", _sec("获奖情况", "awards")),
        ("求职意向", _sec("求职意向", "target")),
        ("自我评价", _sec("自我评价", "self_eval")),
    ]
    sections = [(t, body) for t, body in sections if body]
    pdf_bytes = build_resume_pdf(resume.title or "我的简历", sections)
    filename = f"resume_{resume.id}_v{resume.version}.pdf"
    return Response(
        content=pdf_bytes,
        media_type="application/pdf",
        headers={"Content-Disposition": f'attachment; filename="{filename}"'},
    )
