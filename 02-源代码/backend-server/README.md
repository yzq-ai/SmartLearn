# SmartLearn Backend

《鸿蒙智学业》FastAPI 后端：SQLite/MySQL 可切换的 SQLAlchemy 异步 ORM、BCrypt 密码哈希 + JWT Bearer 鉴权与角色 RBAC、统一响应体 `{code, message, data}`、五题型判分 + 错题归集 + 知识点掌握度与画像匹配引擎，以及无密钥安全降级的 AI 错题分析和简历优化，可选 Redis 限流与交卷分布式锁。

## 运行

```powershell
cd D:\Dev\SmartLearn\smartlearn-backend
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
Copy-Item .env.example .env   # 按需填写 DATABASE_URL / JWT_SECRET / REDIS_URL
uvicorn app.main:app --reload
```

服务启动后：
- 健康检查：`GET http://127.0.0.1:8000/health`（返回 `{status, service}`）
- OpenAPI：`http://127.0.0.1:8000/docs`
- API 前缀：`/api/v1`，成功响应统一为 `{code: 0, message: "ok", data: ...}`

## 配置（`.env`）

| 变量 | 默认值 | 说明 |
|---|---|---|
| `DATABASE_URL` | `sqlite+aiosqlite:///./smartlearn.db` | 生产用 `mysql+aiomysql://...` |
| `JWT_SECRET` | 开发占位值 | 生产必须替换 |
| `REDIS_URL` | 空（禁用） | 填 `redis://host:6379/0` 启用限流与交卷锁 |
| `EXAM_DURATION_MINUTES` | 60 | 考试时长 |
| `AI_REQUESTS_PER_MINUTE` | 10 | AI 限流阈值 |

## 数据模型与迁移

`app/models/__init__.py` 定义文档第 7 章全量 40 张表（用户/课程/测评/就业/服务/AI 统计六域）。三套建表途径保持一致：

1. **开发**：`init_db()` 启动时幂等 `create_all`。
2. **MySQL 全新实例**：`mysql/init/001_schema.sql`（由 ORM 元数据自动生成）。
3. **版本化迁移（Alembic）**：

```powershell
alembic upgrade head        # 应用迁移
alembic revision --autogenerate -m "描述"   # 模型变更后生成新迁移
```

4. **种子数据（独立脚本，交付物）**：

```powershell
python scripts/seed.py            # 建表 + 写入种子（幂等）
python scripts/seed.py --reset    # 删表重建（开发用，慎用）
```

`alembic/env.py` 会自动把异步驱动（aiosqlite/aiomysql）转换为同步驱动（sqlite/pymysql）供迁移使用。种子数据逻辑统一在 `app/seed.py`，`init_db` 与 `scripts/seed.py` 共用，避免两处漂移。

## 演示账号

`student / smartlearn`、`teacher / smartlearn`、`admin / Admin@123456`。种子数据含 6 个知识点、2 场考试（覆盖五种题型）、演示学生能力画像。

## 接口（均返回 `{code, message, data}`）

- **认证**：`POST /auth/login`（返回 access+refresh+pwd_changed）、`POST /auth/register`、`POST /auth/refresh`、`POST /auth/logout`（Token 黑名单）、`PUT /auth/password`（改密）、`POST /users/me/deactivate`、`POST /users/me/deactivate/cancel`；登录防爆破（5 次锁 15 分钟）+ 登录日志
- **课程**：`GET /courses`、`GET /courses/{id}`、`POST /courses`（教师/管理员）
- **进度**：`GET /progress`、`PUT /progress/{course_id}`
- **考试**：`GET /exams`、`GET /exams/{id}`、`POST /exams/{id}/start`、`PUT /exams/{id}/answers`、`POST /exams/{id}/submit`、`GET /exams/{id}/state`
- **作业（M3）**：`POST /assignments`（教师发布）、`GET /assignments`（三态列表）、`POST /assignments/{id}/submit`（学生提交/重复覆盖/迟交标记）、`POST /assignments/{id}/remind`（催交）、`GET /assignments/{id}/submissions`（教师看提交）、`POST /submissions/{id}/grade`（批改/退回重做）
- **错题**：`GET /wrong-questions`、`PUT /wrong-questions/{id}/mastered`
- **画像**：`GET /profile/me`、`POST /profile/refresh`
- **就业**：`GET /jobs/recommendations`（仅审核通过）、`POST /jobs/{id}/applications`、`PUT/DELETE /jobs/{id}/favorite`、`GET /jobs/favorites`
- **就业信息审核（先审后发）**：`POST /jobs`、`POST /companies`（教师/管理员，待审）；`GET /admin/reviews/pending`、`POST /admin/reviews`（管理员审批，驳回必填理由）
- **题库（教师）**：`GET /questions`、`POST /questions`、`PUT /questions/{id}`；`POST /questions/drafts/approve`、`DELETE /questions/drafts/{id}`（AI 草稿采纳/丢弃）
- **学情/数据**：`GET /stats/learning`（教师）、`GET /admin/stats/dashboard`（管理员）
- **异步任务（Celery）**：`POST /admin/tasks/{aggregate-stats|auto-collect|refresh-profile}`（管理员触发）；生产由 Beat 定时执行日统计聚合（02:00）与到时自动收卷（30s）
- **系统管理（管理员）**：敏感词 `GET/POST/DELETE /admin/sensitive-words`、配置 `GET/PUT /admin/configs`、技能标签 `GET/POST/DELETE /admin/skill-tags`、用户 `GET /admin/users` + `PUT /admin/users/{id}/status` + `POST /admin/users/{id}/reset-password` + `POST /admin/users/import`（批量导入带校验报告）、审计日志 `GET /admin/audit-logs`
- **消息**：`GET /notifications`
- **讨论/签到**：`GET/POST /discussions`、`POST /discussions/{id}/replies`、`POST /discussions/{id}/like`、`POST /reports`；`POST /sign/tasks`（教师发起 HMAC 二维码）、`POST /sign/scan`（学生扫码核验）、`GET /sign/tasks/{id}/records`
- **AI（8 场景，规则兜底 + 可选 LLM）**：`POST /ai/wrong-answer/analyze`、`POST /ai/resume/optimize`、`POST /ai/job-explain`、`POST /ai/summary`、`POST /ai/plan`（落 study_plan）、`POST /ai/interview/start`、`POST /ai/interview/turn`、`POST /ai/questions/draft`（落 question 表 DRAFT）、`POST /ai/course-qa`（课程问答 RAG，检索章节内容并落 ai_chat_log）

## 判分规则（`app/services/grading.py`）

- SINGLE / JUDGE：精确匹配（忽略大小写与首尾空格）。
- MULTI：全对满分、漏选 50%、错选或空 0。
- BLANK：多空以 `|||` 分隔，按空位比例给分。
- SHORT：返回 `None`，交卷后状态为 `GRADING`，待教师批改。

交卷后异步落地：错题写入 `wrong_question`，知识点掌握度写入 `student_kp_mastery`，并据此刷新 `student_profile` 技能分与六维雷达。

## 外部服务接入（抽象 + 本地回退）

| 服务 | 模块 | 配置 | 未配置时行为 |
|---|---|---|---|
| 对象存储 OBS | `app/services/obs.py` | `OBS_AK/OBS_SK/OBS_BUCKET/OBS_ENDPOINT` | `POST /resources/upload-token` 返回 `storage=local` 回退 |
| 向量库 RAG | `app/services/vector_store.py` | `VECTOR_BACKEND=memory/qdrant/milvus` | 关键词检索兜底 |
| 推送 Push | `app/services/push_service.py` | `PUSH_BACKEND=log/agc` | 日志占位，通知 `push_sent=1` |

生产接真实服务只需填对应密钥/切换 backend，代码接口与链路不变。

## 测试

```powershell
pytest -q
```

生产剩余：Redis 黑名单与 refresh token 轮换、Push/OBS/RAG 真实后端联调。
