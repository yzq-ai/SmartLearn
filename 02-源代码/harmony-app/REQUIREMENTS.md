# 项目要求覆盖对照表（13 项全量）

> 逐条说明每项要求在鸿蒙智学业（SmartLearn）中的实现位置与方式。

| # | 要求 | 实现位置 | 说明 |
|---|---|---|---|
| 1 | 可安装可运行的鸿蒙 APP，三角色 | `entry/`（HarmonyOS NEXT，API 23） | HAP 构建产物 `entry-default-unsigned.hap`，模拟器实测安装运行；学生 5 Tab / 教师 5 Tab / 管理员 4 Tab；登录后按角色路由 |
| 2 | 教师/管理端内容管理 | CourseManage/CourseEdit/ChapterList、ExamEdit/ExamManage/QuestionBank/QuestionEdit、AssignmentEdit/AssignmentGrading、NotificationPublish、JobPublish/CareerEventPublish/CompanyManage、ResourceUpload | 课程/章节/视频文档（资源上传 OBS）/作业/考试/通知/岗位/招聘活动全链路创建-编辑-发布-管理，均在鸿蒙 APP 内完成 |
| 3 | 学生端学习闭环 | Index(学习中心)/CourseDetail/ChapterList/VideoPlayer/DocPreview、AssignmentList、Exam/ExamNotice/ExamResult、LearningStats、Home 就业 Tab | 课程学习、资料查看、视频播放（AVPlayer 断点+倍速+进度上报）、作业提交、在线考试（三态+倒计时+切屏监控）、成绩查询、学习记录、就业信息浏览全覆盖 |
| 4 | 扩展功能 | WrongBook/WrongPractice/WrongAnalysisPage、Home 讨论区（发帖/回复/点赞/举报）、扫码签到（HMAC 一次性 Token）、Notes、Notifications/NotificationDetail、JobDetail 收藏、ResumeEdit（AI 优化/PDF 导出）、CareerEvent（宣讲会/双选会/实习实践）、LearningStats/DataDashboard | 签到讨论、错题本（含重练+AI 分析）、学习进度（服务端幂等同步）、消息提醒（未读红点+全部已读）、岗位收藏、简历管理、招聘活动（报名）、实习实践、数据统计（三视角看板）全部实现 |
| 5 | 多设备适配+数据同步 | GridRow/GridCol 响应式（sm<600/md<840/lg 断点）、breakpoint 监听、EntryAbility onContinue/onRestoreData | 手机/平板自适应布局；账号（token 落盘 preferences）、学习进度（服务端幂等接口+本地队列补传）、考试信息（服务端倒计时+快照固化）、就业数据（服务端匹配计算）全量云端同步 |
| 6 | LLM/AI 智能体接入 | `.env` 环境变量配置（LLM_API_KEY/LLM_BASE_URL/LLM_MODEL，DeepSeek 示例已写入 .env.example） | OpenAI 兼容协议，DeepSeek/GLM/Qwen 一键切换；未配置密钥自动降级规则引擎 |
| 7 | 业务闭环 | 发布（教师出题/作业/课程/活动）→ 参与（学生答题/提交/投递）→ 记录（进度/错题/掌握度/投递状态）→ 反馈（批改/画像重算/匹配推荐/统计大屏） | 全链路数据落库，管理端可查每个环节；详见 README 九大模块 |
| 8 | 模块数据关联 | 错题→掌握度→画像→岗位匹配→补强课程推荐；课程技能标签→画像技能分→匹配权重 | 例如「排序」答错→掌握度下降→画像技能降→匹配度降→推荐《数据结构与算法》补强，形成跨模块数据链 |
| 9 | 移动习惯+安全 | 底部 Tab 导航+页面栈返回、Toast/内联消息/AlertDialog 三级反馈、骨架屏/空态/异常提示 | JWT 认证+RBAC（接口级权限码）+操作审计（sys_audit_log 只增不删）+登录防爆破+Token 黑名单 |
| 10 | 多端适配与跨设备协同 | 手机（主载体，已实测）+ 平板（响应式布局 sm/md/lg）+ 柔性折叠（断点自动切换）；onContinue/onRestoreData 流转接续 | 3 类终端形态；账号/进度/考试/就业数据服务端同步，接续流转跨设备携带 |
| 11 | AI 说明文档 | **`AI.md`** | 完整说明 AI 功能、输入数据、知识来源、处理过程、输出结果、审核方式 |
| 12 | AI 与业务场景结合 | 8 场景全部绑定课程/考试/就业实体数据（RAG 检索、错题输入、简历 Diff、匹配解释） | 无通用聊天窗口；LLM 只解释不改匹配分数；AI 出题走 DRAFT 审核流 |
| 13 | 内容审核/数据保护/隐私 | 敏感词过滤（讨论/简历/岗位/活动）、先审后发工作流（review_status）、试卷快照固化、切屏监控、双重脱敏（ai_security.py）、审计日志（ai_chat_log/sys_audit_log）、简历投递快照 | 详见 AI.md 第八节 + README M9 系统管理 |

## 快速验证指引

1. **构建安装**：DevEco 打开工程 → Build HAP → hdc install（或模拟器直接 Run）
2. **后端启动**：`cd smartlearn-backend && pip install -r requirements.txt && python -m uvicorn app.main:app --port 8000`（模拟器访问 `http://10.0.2.2:8000`）
3. **账号**：admin / teacher1–5 / student01–20，密码统一 `1015401x`
4. **AI 接入**：配置 `.env` 三变量（DeepSeek 示例见 AI.md），或保持空用规则引擎降级
5. **业务闭环演示路径**：teacher1 发布作业 → student01 提交 → teacher1 批改打分 → student01 看评语 → 错题归集 → AI 分析 → 画像更新 → 岗位匹配变化 → 推荐补强课程
