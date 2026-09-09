"""PDF 生成工具：reportlab 真实 PDF（中文用 STSong-Light CID 字体，无需字体文件）。

reportlab 不可用时降级为 UTF-8 文本。
"""
from __future__ import annotations

import logging

logger = logging.getLogger(__name__)

try:
    from reportlab.lib.pagesizes import A4
    from reportlab.lib.styles import ParagraphStyle
    from reportlab.lib.units import mm
    from reportlab.lib.enums import TA_CENTER
    from reportlab.pdfbase.cidfonts import UnicodeCIDFont
    from reportlab.pdfbase import pdfmetrics
    from reportlab.platypus import Paragraph, SimpleDocTemplate, Spacer

    _HAS_REPORTLAB = True
except ImportError:  # pragma: no cover
    _HAS_REPORTLAB = False

try:
    pdfmetrics.registerFont(UnicodeCIDFont("STSong-Light"))
    _CN_FONT = "STSong-Light"
except Exception:  # pragma: no cover
    _CN_FONT = "Helvetica"


def _style(name: str = "body", size: int = 11, bold: bool = False, align=0, color=None) -> "ParagraphStyle":
    kwargs: dict = {}
    if color is not None:
        kwargs["textColor"] = color
    return ParagraphStyle(
        name,
        fontName=_CN_FONT,
        fontSize=size,
        leading=size * 1.6,
        alignment=align,
        spaceAfter=4,
        **kwargs,
    )


def build_resume_pdf(title: str, sections: list[tuple[str, str]]) -> bytes:
    """生成简历 PDF。sections: [(区块标题, 内容), ...]"""
    if not _HAS_REPORTLAB:
        # 降级：UTF-8 文本
        lines = [title, "=" * 40, ""]
        for head, body in sections:
            lines += [head, "-" * 20, body or "", ""]
        return ("\n".join(lines)).encode("utf-8")

    import io

    buf = io.BytesIO()
    doc = SimpleDocTemplate(
        buf, pagesize=A4,
        leftMargin=18 * mm, rightMargin=18 * mm, topMargin=16 * mm, bottomMargin=16 * mm,
        title=title,
    )
    story = [
        Paragraph(title, _style("title", 18, bold=True, align=TA_CENTER)),
        Spacer(1, 8),
    ]
    for head, body in sections:
        if not (head or body):
            continue
        story.append(Paragraph(f"■ {head}", _style("h", 13, bold=True)))
        for line in (body or "").splitlines():
            story.append(Paragraph(line if line.strip() else "&nbsp;", _style()))
        story.append(Spacer(1, 6))
    doc.build(story)
    return buf.getvalue()


def generate_pdf_text(title: str, content: str) -> bytes:
    """兼容旧签名：单段正文 PDF。"""
    return build_resume_pdf(title, [("正文", content)])


def resume_to_text(resume_data: dict) -> str:
    lines = []
    basic = resume_data.get("basic", resume_data)
    if isinstance(basic, dict):
        for key, value in basic.items():
            lines.append(f"{key}: {value}")
    for section in ["education", "skills", "projects", "internships", "self_eval"]:
        data = resume_data.get(section, "")
        if data:
            lines.append(f"\n--- {section.upper()} ---\n{data}")
    return "\n".join(lines)
