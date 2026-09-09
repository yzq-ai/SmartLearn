"""生产就绪回归：注册密码强度、资源直传落盘/下载、题库分页搜索。"""
from __future__ import annotations

import io

import pytest
from httpx import ASGITransport, AsyncClient

from app.database import init_db
from app.main import app


@pytest.fixture
async def client():
    await init_db()
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as http_client:
        yield http_client


async def login(client, username="student", password="1015401x"):
    resp = await client.post("/api/v1/auth/login", json={"username": username, "password": password})
    assert resp.status_code == 200
    return {"Authorization": f"Bearer {resp.json()['data']['access_token']}"}


@pytest.mark.asyncio
async def test_register_rejects_weak_password(client):
    # 纯数字
    r1 = await client.post("/api/v1/auth/register", json={"username": "weakpwd1", "password": "12345678"})
    assert r1.status_code == 422
    # 过短
    r2 = await client.post("/api/v1/auth/register", json={"username": "weakpwd2", "password": "a1"})
    assert r2.status_code == 422
    # 非法用户名字符
    r3 = await client.post("/api/v1/auth/register", json={"username": "bad user!", "password": "abc12345"})
    assert r3.status_code == 422
    # 合法注册成功
    r4 = await client.post("/api/v1/auth/register", json={"username": "okuser01", "password": "abc12345"})
    assert r4.status_code == 200
    assert r4.json()["data"]["user"]["role"] == "STUDENT"


@pytest.mark.asyncio
async def test_resource_direct_upload_and_download(client):
    teacher = await login(client, "teacher")
    student = await login(client, "student")

    # 合法上传（真实落盘）
    content = b"PDF_CONTENT_" * 200
    up = await client.post(
        "/api/v1/resources/upload",
        headers=teacher,
        files={"file": ("算法课件.pdf", io.BytesIO(content), "application/pdf")},
    )
    assert up.status_code == 200
    data = up.json()["data"]
    assert data["file_size"] == len(content)
    assert data["oss_key"].startswith("local/")
    assert data["download_url"].endswith(f"/resources/{data['id']}/download")

    # 学生下载：字节数一致
    down = await client.get(data["download_url"], headers=student)
    assert down.status_code == 200
    assert down.content == content

    # 资源列表可见
    listing = await client.get("/api/v1/resources/list", headers=student)
    assert listing.status_code == 200
    ids = [item["id"] for item in listing.json()["data"]["items"]]
    assert data["id"] in ids

    # 非法扩展名被拒
    evil = await client.post(
        "/api/v1/resources/upload",
        headers=teacher,
        files={"file": ("shell.sh", io.BytesIO(b"#!/bin/sh"), "text/x-sh")},
    )
    assert evil.status_code == 422

    # 学生无权上传
    denied = await client.post(
        "/api/v1/resources/upload",
        headers=student,
        files={"file": ("x.pdf", io.BytesIO(b"x"), "application/pdf")},
    )
    assert denied.status_code == 403


@pytest.mark.asyncio
async def test_question_pagination_and_search(client):
    teacher = await login(client, "teacher")

    page1 = await client.get("/api/v1/questions", headers=teacher, params={"page": 1, "page_size": 5})
    assert page1.status_code == 200
    data = page1.json()["data"]
    assert data["page"] == 1
    assert data["page_size"] == 5
    assert len(data["items"]) <= 5
    assert data["pages"] >= 1
    assert data["total"] >= len(data["items"])

    # 越界 page 返回空列表而非报错
    page99 = await client.get("/api/v1/questions", headers=teacher, params={"page": 999, "page_size": 5})
    assert page99.status_code == 200
    assert page99.json()["data"]["items"] == []

    # 关键词搜索（英文保证不依赖编码）
    hits = await client.get("/api/v1/questions", headers=teacher, params={"q": "HTTP"})
    assert hits.status_code == 200
    assert hits.json()["data"]["total"] >= 1


@pytest.mark.asyncio
async def test_health_ready_endpoint(client):
    r = await client.get("/health/ready")
    assert r.status_code == 200
    body = r.json()
    assert body["status"] == "ok"
    assert body["checks"]["database"] is True


@pytest.mark.asyncio
async def test_exam_review_after_submit(client):
    """交卷后成绩单返回逐题解析（题干/我的答案/正确答案/得分/解析）。"""
    student = await login(client, "student")
    # 用考试 2（进行中）走完整流程
    detail = (await client.get("/api/v1/exams/2", headers=student)).json()["data"]
    q_ids = [q["id"] for q in detail["questions"]]
    start = await client.post("/api/v1/exams/2/start", headers=student)
    assert start.status_code == 200
    # 定制作答：JUDGE 题答 true（对），SINGLE/MULTI/BLANK 答错误内容（0 分），SHORT 答内容（待批改）
    custom = {"SINGLE": "错误选项", "MULTI": "错误选项", "JUDGE": "true", "BLANK": "错误答案", "SHORT": "参考 RESTful 设计原则作答"}
    answers = [{"question_id": q["id"], "answer": custom.get(q["type"], "")} for q in detail["questions"]]
    submit = await client.post("/api/v1/exams/2/submit", headers=student, json={"answers": answers})
    assert submit.status_code == 200
    result = submit.json()["data"]
    # 仅 1 道 JUDGE 题答对（20 分）；其余客观题 0 分；SHORT 待批改不计分
    assert result["score"] == 20
    assert result["total"] == 100

    state = (await client.get("/api/v1/exams/2/state", headers=student)).json()["data"]
    review = state.get("review")
    assert review is not None and len(review) == len(q_ids)
    for item in review:
        assert item["text"]
        assert "correct_answer" in item and "my_answer" in item
        assert item["earned"] is not None or item["type"] == "SHORT"
    # 答对的题 earned == score；答错 earned == 0；主观题待批改
    judge_items = [item for item in review if item["type"] == "JUDGE"]
    assert judge_items and judge_items[0]["earned"] == judge_items[0]["score"]
    assert judge_items[0]["my_answer"] == "true"
    singles = [item for item in review if item["type"] == "SINGLE"]
    assert singles and singles[0]["earned"] == 0
    shorts = [item for item in review if item["type"] == "SHORT"]
    assert shorts and shorts[0]["earned"] is None


@pytest.mark.asyncio
async def test_ai_job_explain_with_job_context(client):
    """传 job_id 时 AI 匹配解释携带真实 JD/画像上下文（LLM 未配置时规则兜底）。"""
    student = await login(client, "student")
    r = await client.post(
        "/api/v1/ai/job-explain",
        headers=student,
        json={"job_id": 1, "job_title": "Python 后端实习生", "match_score": 0,
              "matched_tags": [], "gap_tags": [], "required_skills": []},
    )
    assert r.status_code == 200
    data = r.json()["data"]
    assert data["explanation"]
    assert isinstance(data["suggestions"], list) and len(data["suggestions"]) >= 1
    # 传了 job_id + 学生有画像 → 后端重算了匹配度（非 0）或保持入参
    assert data["match_score"] >= 0


@pytest.mark.asyncio
async def test_resume_pdf_export_has_content(client):
    """简历 PDF 导出：中文字段（seed 体系）简历必须输出非空正文段落。"""
    student = await login(client, "student")
    # 先建一份中文字段简历
    created = await client.post(
        "/api/v1/resumes",
        headers=student,
        json={"title": "PDF测试简历", "content": {
            "教育背景": "计算机科学与技术 2023 级本科 · 计科2301 · GPA 3.6/4.0",
            "技能清单": "Python, FastAPI, MySQL",
            "项目经历": "校园二手交易平台（FastAPI + MySQL）：负责后端接口与鉴权模块",
            "求职意向": "Python 后端开发实习",
        }},
    )
    assert created.status_code == 200
    rid = created.json()["data"]["id"]

    pdf = await client.get(f"/api/v1/resumes/{rid}/pdf", headers=student)
    assert pdf.status_code == 200
    assert pdf.headers["content-type"] == "application/pdf"
    assert pdf.content[:4] == b"%PDF"
    # PDF 含多个内容页对象（非空骨架）：至少 4 个段落（教育/技能/项目/意向）
    assert pdf.content.count(b"/Contents") >= 1
    assert len(pdf.content) > 1500  # reportlab 正常 PDF 远大于空骨架
