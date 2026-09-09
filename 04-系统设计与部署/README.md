# 鸿蒙智学业（SmartLearn on HarmonyOS）

覆盖"教、学、练、测、评、就业"全链路，以学习数据驱动就业推荐、AI 智能体贯穿教学与求职场景的鸿蒙一体化人才培养平台。

## 项目概述

| 项目 | 内容 |
|---|---|
| 应用形态 | HarmonyOS NEXT 原生 APP（一包三角色）+ Python 云端服务 |
| 目标设备 | 手机（主载体）、平板（自适应布局）、智慧屏（投播） |
| 端侧系统 | HarmonyOS NEXT API 23（6.1.0） |
| 后端语言 | Python 3.11+，FastAPI 框架 |
| 后端数据库 | MySQL 8.0（SQLAlchemy ORM + aiomysql 驱动） |
| 应用包名 | `com.smartlearn.app` |
| 版本号 | 1.0.0（versionCode: 1000000） |

### 目标用户

| 角色 | 画像 | 核心诉求 |
|---|---|---|
| 学生 | 在校大学生 18~24 岁 | 一处完成学习、考试、查成绩、找实习；个性化提升建议 |
| 教师 | 授课教师/就业指导教师/辅导员 | 一次发布多端同步；掌握学情；AI 减负出题批改 |
| 管理员 | 教务/就业中心管理员 | 内容合规可控；全校数据可视；账号统一管理 |

### 核心特性

- **三角色端侧**：登录后按角色进入对应 Tab 导航，共 50 个独立页面
  - 学生 5 Tab：[学习][考试][就业][消息][我的]
  - 教师 5 Tab：[授课][题库][学情][通知][我的]
  - 管理 4 Tab：[工作台][审核][数据][设置]
- **认证安全**：BCrypt + JWT（access 1h / refresh 7d）、登出 Token 黑名单、登录防爆破（5 次锁 15 分钟）、首次登录强制改密、注销 7 天冷静期、完整 RBAC 权限码；**access token 过期自动登出回登录页**（401 静默清理 + 落盘清除，登录接口自身 401 = 密码错误不触发登出，原样提示）
- **登录态持久化**：token/role/username 落盘（preferences），进程被杀或重启后免登录直达首页；Splash 启动渐进检查（4 次重试 + 兜底跳登录页，永不卡死）
- **学习**：课程/章节/小节、服务端进度幂等同步、资源上传（OBS 预签名）
- **考试**：五题型判分（SINGLE/MULTI/JUDGE/BLANK/SHORT）、试卷快照、切屏监控、强制收卷、错题归集、掌握度与画像；**考试三态列表**（🔴进行中呼吸动效+实时倒计时 / 📝未开始+开考倒计时 / ✅已结束直达成绩单）；**deadline UTC 序列化修复**（naive UTC → ISO 带 `Z`，前端 `new Date()` 跨时区正确解析，修复非 UTC 时区进入考试即 0:00 自动交卷）
- **就业**：基于个人画像 + 岗位技能权重的可解释匹配、gap 反查补强课程、投递状态流转、简历快照固化、先审后发；**岗位卡匹配环分数色阶**（≥75 绿 / ≥60 蓝 / 待提升橙）；**投递记录四节点时间线**（依序点亮动画：已投递→被查看→面试→Offer）；**简历 AI 优化 Diff 逐条采纳**（原文删除线→建议稿→理由，采纳回填绝不覆盖原文）；**简历一键导出 PDF**（reportlab 真实 PDF，中文字体 STSong-Light，保存至应用文件目录）
- **作业/讨论/签到**：作业发布/提交/批改/退回重做、讨论区与举报、HMAC 扫码签到、通知已读；**首页作业区仅展示 3 条 + 查看全部入口**；截止时间本地时区格式化
- **消息中心**：通知卡片点击进入消息详情页（完整正文 + 类型徽章 + 发布时间）；**未读红点脉冲 + NEW 角标 + 未读计数徽章 + 全部已读**；点击即读（数组整体替换保证 UI 即时刷新）
- **题库详情编辑**：题库中点击题目卡片进入详情视图（题干/选项/答案/解析），一键切换编辑模式保存
- **数据可视化**：
  - 教师学情统计：平均分环形图、能力雷达图、课程选课人数柱状图、高频错题柱状图、考试参与人数柱状图
  - 管理员数据大屏：内容分布环形图、核心指标柱状图（工作台与独立大屏页均支持）；**近 7 日活跃用户趋势（DAU 折线图）**；**投递转化漏斗**（收藏→投递→被查看→面试→Offer）
- **AI（8 场景）**：课程问答 RAG、内容摘要、学习计划、题目生成（DRAFT 审核流）、错题分析、简历优化、岗位推荐解释、面试模拟；SSE 流式 + 赞踩反馈；**AI 解释匹配弹窗化**（就地 AlertDialog 展示）；**错题分析 👍👎 反馈落库**（log_id 闭环）
- **异步/管理**：Celery 日统计聚合、自动收卷、画像重算；管理端审核/题库/用户/配置/审计/数据大屏；**举报讨论审核**（🚩帖子/回复卡：恢复展示/驳回下架）；**用户批量导入**（多行粘贴 `用户名,姓名,角色`，逐条失败原因报告）
- **接口契约**：`/api/v1` 统一返回 `{code, message, data}`；`/health` 除外
- **动效体系**：Splash 呼吸光圈、登录页三光晕呼吸 + 失败抖卡 + 第三方登录按压反馈、首页 stagger 入场（快捷条→列表→数据区渐次浮现）、能力画像技能条生长动画、未读红点脉冲、进行中考试呼吸图标
- **深色模式**：Theme 全量动态色板（getter 双态切换），设置开关**立即生效**（@StorageProp 全局重建）+ preferences 持久化（重启保持）
- **IBest-UI-V2 组件库集成（v1.1.3）**：`@ibestservices/ibest-ui-v2` 接入（compatibleSdkVersion 6.0.1(21)），`IBestInit` 于 EntryAbility 启动；**深浅双套品牌色**注入 base/dark color.json（primary #3D5AFE/#5C7CFF 等）；命令式 API **IBestToast / IBestDialogUtil** 替换原生 Toast/AlertDialog 全站生效（登录提示、考试交卷确认、AI 匹配解读弹窗）；Home **IBestNoticeBar** 滚动通知条（未读播报）；Settings 页 **@ComponentV2 重构**（IBestCellGroup/IBestCell/IBestSwitch 设置行交互）；Login 页 IBestCheckbox 记住我；V1 页面与 V2 组件混用经验：**命令式 API 安全**，组件插槽/事件在 V1 页面存在静默失效——交互组件仅用于 V2 页（Settings 为模板），PrimaryButton/TagChip/EmptyState/PageHeader 保持原生增强底座（50 页零侵入换肤）
- **讨论点赞**：一人一帖一次（discussion_like 唯一约束幂等），重复点赞返回当前计数；列表返回 liked_by_me，已赞按钮置灰显示「已赞」
- **技能归一匹配**：知识点名→岗位技能名别名映射（Python 基础→Python 等 20 条），匹配度按归一后加权计算；岗位详情返回 skill_scores 真值供雷达图渲染
- **招聘活动/实习实践**：独立 career_event 域（宣讲会/双选会/实习实践三类），教师端「活动发布」表单（类型单选+时间校验+敏感词过滤），学生端「招聘活动」页（类型筛选+报名幂等+报名数回显），入口位于就业 Tab 与我的页
- **真实化种子数据**：每门课 **8 章×4 小节**（真实教学大纲：Python 基础语法→项目实战/线性表→动态规划/SQL 基础→NoSQL 导论等 40 章 158 节），题库 **147 道真实题**（单选/多选/判断/填空/简答×4 难度，题干/答案/解析全部为真实内容非占位），讨论帖为真实技术问答（依赖注入 sync/async、快排退化、索引变慢、三次握手等），6 企业 21 岗位、9 通知、3 考试（含进行中）、4 招聘活动、签到任务+记录
- **动效体系 v2**：骨架屏 **shimmer 流光**、Card/PrimaryButton **按压回弹**、TagChip **弹簧浮现**、IconBadge **缩放入场**、StatTile **数字滚动**、EmptyState **上下浮动**、BarChart **柱体生长+错峰动画**、错题卡片 **stagger 依次浮现**；全部实现在全局组件（UiKit/BarChart），所有页面自动获得
- **pytest 数据库隔离**：tests/conftest.py 将测试指向独立临时库（DATABASE_URL 注入临时目录），pytest 全程零污染演示库；测试依赖种子布局的用例已改为动态取数（考试题 id/画像键）
- **生产就绪加固（市场交付级）**：
  - **资源真实落盘闭环**：本地模式 multipart 直传端点（`POST /resources/upload`，流式写盘 50MB 上限+扩展名白名单+文件名净化防路径穿越），下载端点 `GET /resources/{id}/download` 以 FileResponse 回源（OBS 模式自动 302 预签名）；学生端新增「学习资料」页（类型筛选+下载+分享），种子自带 5 份真实讲义（Python 环境指南/FastAPI 速查/排序讲义/索引实验/抓包实验）
  - **题库分页**：`GET /questions` 支持 page/page_size（≤100）+ 题干模糊搜索 q；教师端题库管理页升级分页条+搜索框；组卷页循环拉页聚合
  - **注册密码强度**：RegisterRequest 强校验（8-64 位须含字母数字+用户名 3-32 位字母数字下划线）
  - **启动安全体检**：JWT_SECRET/CORS/SQLite 三风险项启动告警 + `/health/ready` 就绪探针（数据库连通+存储可写+风险计数）；`/health` 存活探针带版本
  - **限流中间件重构**：Redis 连接惰性建连复用（原每请求新建连接）；无 Redis 时进程内滑动窗口降级（原完全不限流）；健康探针豁免；支持 RATE_LIMIT_DISABLED
  - **Token 黑名单三级持久化**：Redis → SQLite revoked_token 表（服务重启不失效）→ 内存兜底
  - **全局 422 序列化修复**：pydantic v2 ctx 含异常对象导致 JSONResponse TypeError（任何带校验器的接口 422 必崩）——统一转 str 后返回
- **交互升级六项（评审反馈轮）**：
  - **考试交卷后逐题解析**：成绩单新增「📝 逐题解析」（展开/收起），每题卡片含题型徽章、得分标签（✓满分/半对/✗0分/待批改）、题干、选项（正确项高亮绿）、「我的答案 vs 正确答案」双栏、📖 解析；后端 `exams/{id}/state` 在 SUBMITTED/GRADING/GRADED 返回 `review[]`（题干/选项/我的答案/正确答案/得分/解析），答题过程不泄漏答案
  - **就业 AI 匹配解析（真实上下文）**：`POST /ai/job-explain` 传 job_id 时后端自动加载真实 JD/技能权重/薪资城市学历 + 学生画像 top8 技能，组装富 Prompt 调真实 LLM（OpenAI 兼容，LLM_API_KEY 配置即生效；未配置规则引擎兜底并如实标注 `source`）；前端未传匹配数据时服务端按画像+权重重算；岗位详情页新增「🤖 AI 匹配解析」卡（生成按钮+行动建议+来源徽章+换角度分析）
  - **课堂签到 v2（4 位数字码）**：教师发起 → 大号 4 位数字格 + 30 秒倒计时进度条 + 剩余秒徽标；考勤名单（应到/已签/未签统计 + 全体选课学生逐行 已签✓/未签✗）+ 教师手动「补签/作废」；学生端「📍 课堂签到」卡（刷新拉最新任务 → 数字键盘输 4 位码 → 倒计时 → 立即签到），错码 403、过期 410、重复幂等；`sign/tasks|tasks/latest|checkin|attendance|manual` 五端点
  - **学情图表防重叠**：RadarChart/ScoreRingChart/DonutChart 由固定像素宽改 `onAreaChange` 容器自适应（Canvas 随容器收缩，雷达图标签超宽截断），窄容器/分栏场景不再溢出重叠；零调用方改动
  - **通知未读红点**：学生「🔔 消息」/教师「📢 通知」Tab 红色数字徽标（>99 显 99+），基于通知列表 is_read 响应式重算，点击已读后自动减；通知按 target_role 角色定向（学生看不到教师通知）
  - **教师课程章节修复**：授课卡「进入课程」全量 8 章 32 节正常展示（旧包数据问题），章节目录 + 「N 个小节」逐层可进
- **真实数据治理（本轮）**：
  - **清理**：6 个 API 测试残留用户（stu_\*/pwd_\*）及其 18 条孤儿错题/画像/进度；6 条测试作业（单元测试/锁定作业）+6 份提交；3 条 HMAC 旧签到任务；user 28 重复学习计划×2 与 6 份 44 字节占位简历；17 条孤儿画像/34 条孤儿知识点掌握；教师误选课 3 门；清理后 14 项一致性检查全过（孤儿 0/占位 0/空描述 0/计数同步 0 偏差）
  - **修复**：course#1 标题/描述物理乱码（????）→「Python 后端开发」；course.skill_tags 裸文本坏 JSON 导致 `GET /courses` 500 → 修为合法 JSON 数组 + `/courses` 加行级容错（单行坏数据不再打挂整列表）；简历 PDF 导出中英字段双兼容（seed 中文键 ↔ 部分历史英文键）
  - **补真**：占位岗位「待审核岗位/待审核数据岗」→「嵌入式软件开发实习生/数据分析实习生（BI 方向）」（真实 JD/技能权重/薪资，保留待审核态供审核流演示）；课程 4/5 选课 1→11 人（含进度）；作业 3/4 提交 0→33 份（3 已批改带评语）；student11-20 + 演示学生真实简历 11 份（教育背景/技能/项目/校园经历/获奖/求职意向六段式）；招聘活动报名 1→46 人；学习计划充实（28 号四周期里程碑）+3 名学生新增；投递 19→31（新增岗位 14-19 全覆盖含拒信理由）；收藏 1→9、讨论点赞 1→21；新通知「期末复习周安排发布」（ALL）验证学生红点
  - **seed 同步**：简历覆盖全部 20 名学生（原仅前 10）+ 校园经历/获奖/求职意向字段，与库内数据风格一致
- **十七项体验升级（第三轮）**：
  - **修复 7 项**：①改用户名后顶部实时同步（onPageShow 刷新 + AppStorage）②聊天键盘弹起自动滚底（onFocus 延时 + onAreaChange 高度追踪）③④学生/教师端底部 Tab 文字基线对齐（TabBadge 重写：文本与原生 Tab 同款、徽标 markAnchor 浮层不再挤占布局）⑤教师「我的老师」→角色感知「我的学生」（师生双向关系同一数据源）⑥学情高频错题 TOP 图表 chartHeight 解除 220px 裁剪（不再重叠）⑦课程详情 8 章全量一屏可见（大卡片改紧凑单行列表）
  - **用户号登录（需求 14）**：`POST /auth/login` 支持 `username` 或 `SLxxxxxx` 用户号（自动识别 SL 前缀）；登录页占位「用户名 / 用户号（SL 开头）」；改用户名撞库时 409「用户名已被占用」红条提示（后端查重已有）
  - **教师课程内容管理（需求 6 教师侧）**：`/courses/manage/*` 七端点（章节 CRUD + 小节 CRUD + 视频上传 token），授课教师/管理员鉴权（他人 403）；CourseContentManage 页：章节树折叠展开、行内编辑章节（标题/简介）、新增/编辑/删除小节（标题/类型 TEXT·VIDEO·QUIZ/正文/视频地址/分秒时长）；我的授课卡「管理内容」入口
  - **小节学习页（需求 6 学生侧）**：SectionLearn 一体化——Video 组件在线播放 + 图文正文；讨论区显示 用户号+用户名（如 SL000013 吴雅琪），发帖/回复（可对回复再回复）/帖子点赞/回复点赞/10 个 emoji 快捷表情（👍❤️😂😮😢🎉🔥✨🙏💯）；帖子详情接口含回复树+作者+双维度点赞状态
  - **教学讨论区（需求 9）**：`/discussions/teacher-room` GET/POST（TEACHER/ADMIN，学生 403 已测）；course_id=0 专属空间；TeacherRoom 页：发帖卡 + 帖子流（教师徽章/点赞/展开）；教师端「教研」快捷入口
  - **组卷建考重做（需求 8）**：ExamEdit 全新——课程下拉（真实课程循环切换）、智能随机抽题（数量/题型偏好/难度 + 本地洗牌）、题型·难度·关键词筛选题库（后端 questions 接口新增 course_id/type/difficulty 参数）、实时统计（题数/总分/及格线校验/题型分布/难度分布）、展开题干预览；真实题库 5 课程 156 题
  - **讨论广场（需求 16）**：课程讨论标题右侧「讨论广场 ›」→ 全站讨论流，10/50/100 条每页切换 + 翻页器 + 总帖数；帖子展开详情（回复树/回复点赞/emoji 回复）
  - **管理员控制台（需求 10/11/12）**：删除与「数据」完全重复的「工作台」Tab（3 Tab：数据看板/审核/设置）；新增渐变欢迎横幅（真实指标：用户/课程/待审）+ 6 宫格快捷管理入口（用户/企业/通知/日志/配置/敏感词）；保留环形图/柱状图/DAU 折线/投递漏斗四图表
  - **教师互加好友（需求 4）**：seed 增 teacher1↔teacher2 ACCEPTED + teacher3→teacher1 PENDING（生产库已同步）；好友/师生关系教师间可用，我的学生中教师可与学生聊天（同一 TEACHER 关系双向数据源）
  - **考试交卷（需求 17）**：IBestDialogUtil.onConfirm 在 V1 页静默失效 → 原生 `getUIContext().showAlertDialog`（继续答题/确认交卷双按钮），交卷链路恢复

## 九大功能模块

| 模块 | 说明 |
|---|---|
| M1 用户与认证 | 登录/登出、邀请码注册、找回密码、资料维护、头像上传、注销、登录日志 |
| M2 课程学习 | 课程 CRUD、章节/小节、OBS 直传、视频播放（断点/倍速）、文档预览、进度记录同步 |
| M3 作业 | 发布（附件/分值/截止）、三态列表、提交、迟交标记、批改回传推送 |
| M4 考试测评 | 五题型判分、组卷、快照固化、服务端倒计时、切屏监控、自动收卷、错题归集、掌握度画像 |
| M5 就业服务 | 画像匹配算法、岗位推荐解释、投递状态机、简历编辑/快照/AI 优化/导出 PDF、先审后发 |
| M6 消息与学生服务 | 四类通知（中文分类标签）、Push Kit、扫码签到、讨论区、日程提醒 |
| M7 AI 智能体 | 8 场景全流程：双重脱敏 → RAG 检索 → Prompt → LLM → 输出过滤 → 审计 |
| M8 数据统计 | Celery Beat 每日聚合、学生/教师/管理三视角看板、openpyxl 导出 |
| M9 系统管理 | 审核流、批量导入、操作审计（只增不删）、敏感词库、系统配置热生效 |
| M10 反馈中心 | 学生/教师五类反馈提交（缺陷/建议/体验/纠错/其他）、我的反馈进度跟踪、管理端状态机处理（待处理→处理中→已解决/驳回）+ 回复闭环 |

## 工程结构

```text
SmartLearn/
├── AppScope/                              # 应用配置与全局资源（bundleName: com.smartlearn.app）
│   ├── app.json5                          # 应用信息（包名/版本/图标）
│   └── resources/base/element/string.json # 全局字符串资源
├── entry/
│   ├── build-profile.json5                # 模块构建配置
│   ├── hvigorfile.ts                      # 模块构建脚本
│   ├── oh-package.json5                   # 模块依赖
│   └── src/main/
│       ├── module.json5                   # 模块配置（权限/Ability/页面路由）
│       ├── ets/
│       │   ├── entryability/
│       │   │   └── EntryAbility.ets       # 应用入口 Ability（Token 持久化恢复 + 路由）
│       │   ├── common/
│       │   │   ├── ApiClient.ets          # 网络层（统一响应体解析 + Bearer + 重试）
│       │   │   ├── TokenStore.ets         # 登录态磁盘持久化（preferences）
│       │   │   └── Models.ets             # 端侧数据模型（45+ 接口定义）
│       │   ├── components/
│       │   │   ├── UiKit.ets              # 通用组件（PageHeader/PrimaryButton/Card/…）
│       │   │   ├── RadarChart.ets          # 能力雷达图（Canvas）
│       │   │   ├── ScoreRingChart.ets      # 分数环形图（Canvas）
│       │   │   ├── BarChart.ets           # 横向柱状图（渐变柱体）
│       │   │   ├── DonutChart.ets          # 环形分布图（甜甜圈 + 图例）
│       │   │   └── TrendChart.ets          # 折线趋势图（渐变面积）
│       │   └── pages/                     # 50 个页面
│       │       ├── Login.ets              # 登录页（深色渐变 + 玻璃卡 + 注册引导）
│       │       ├── Home.ets               # 三角色主页面（Tab 导航 + 数据大屏图表 + 消息详情入口）
│       │       ├── Index.ets              # 学习中心（课程列表+进度）
│       │       ├── Exam.ets               # 答题页
│       │       ├── ExamNotice.ets         # 考试须知
│       │       ├── ExamResult.ets         # 成绩单
│       │       ├── ExamEdit.ets           # 组卷建考
│       │       ├── ExamMonitor.ets        # 考试监控
│       │       ├── ExamManage.ets         # 考试管理
│       │       ├── WrongBook.ets          # 错题本
│       │       ├── WrongPractice.ets      # 错题重练
│       │       ├── WrongAnalysisPage.ets  # 错题 AI 分析
│       │       ├── QuestionBank.ets       # 题库管理（整卡点击进详情）
│       │       ├── QuestionEdit.ets       # 题目详情 + 编辑双模式
│       │       ├── AssignmentList.ets     # 作业列表
│       │       ├── AssignmentEdit.ets     # 作业编辑
│       │       ├── AssignmentGrading.ets  # 作业批改
│       │       ├── JobDetail.ets          # 岗位详情
│       │       ├── JobPublish.ets         # 岗位发布
│       │       ├── Applications.ets       # 投递记录
│       │       ├── ResumeEdit.ets         # 简历编辑
│       │       ├── UserManage.ets         # 用户管理
│       │       ├── CompanyManage.ets      # 企业管理
│       │       ├── CourseManage.ets       # 课程管理
│       │       ├── CourseEdit.ets         # 课程编辑
│       │       ├── ConfigManage.ets       # 系统配置管理
│       │       ├── SkillTagManage.ets     # 技能标签管理
│       │       ├── AuditLogs.ets          # 操作日志
│       │       ├── DataDashboard.ets      # 数据大屏（环形图 + 柱状图）
│       │       ├── DiscussionManage.ets   # 讨论管理
│       │       ├── Notifications.ets      # 消息通知（点击进详情）
│       │       ├── NotificationDetail.ets  # 消息详情页
│       │       ├── NotificationPublish.ets# 通知发布
│       │       ├── Settings.ets           # 设置
│       │       ├── ChangePassword.ets     # 修改密码
│       │       ├── ForgotPassword.ets     # 找回密码
│       │       ├── VideoPlayer.ets        # 视频播放（占位）
│       │       ├── DocPreview.ets         # 文档预览（占位）
│       │       ├── ResourceUpload.ets     # 资源上传（占位）
│       │       ├── Notes.ets              # 笔记
│       │       ├── AISummary.ets          # AI 摘要
│       │       └── SubjectiveGrading.ets  # 主观题批改
│       └── resources/base/
│           ├── profile/main_pages.json    # 页面路由注册
│           └── element/                   # 字符串/颜色资源
├── smartlearn-backend/                    # FastAPI 后端
│   ├── app/
│   │   ├── main.py                        # FastAPI 入口（中间件/路由/生命周期）
│   │   ├── core/                          # 核心模块
│   │   │   ├── config.py                  # Pydantic Settings（读 .env）
│   │   │   ├── security.py                # JWT 签发/验证、密码哈希、Token 黑名单
│   │   │   ├── deps.py                    # 依赖注入：get_db / get_current_user / require_perm
│   │   │   ├── exceptions.py              # 统一业务异常 BizError + 全局异常处理器
│   │   │   ├── response.py                # 统一响应体 {code, message, data}
│   │   │   ├── audit.py                   # @audit 装饰器 + AOP 式审计中间件
│   │   │   └── constants.py               # 枚举：角色/题型/状态机/错误码
│   │   ├── models/                        # SQLAlchemy ORM 模型（40 表）
│   │   │   └── user.py                    # 用户模型
│   │   ├── schemas/                       # Pydantic 请求/响应模型
│   │   │   ├── auth.py                    # 认证相关
│   │   │   ├── learning.py                # 学习相关
│   │   │   ├── jobs.py                    # 就业相关
│   │   │   └── ai.py                      # AI 相关
│   │   ├── api/                           # 路由层（薄，只做参数与权限）
│   │   │   ├── routes.py                  # 基础路由（健康检查/认证/课程/考试/就业等）
│   │   │   ├── assignment_routes.py       # 作业路由
│   │   │   ├── ai_routes.py               # AI 场景路由
│   │   │   ├── admin_routes.py            # 管理端路由
│   │   │   └── service_routes.py          # 服务层路由
│   │   ├── services/                      # 业务逻辑层（核心）
│   │   │   ├── grading.py                 # 判分器（纯函数，五题型规则）
│   │   │   ├── match_engine.py            # 岗位匹配规则引擎（纯函数）
│   │   │   ├── mastery_service.py         # 掌握度与画像计算
│   │   │   ├── assessment_service.py      # 考试引擎
│   │   │   ├── ai_service.py              # AI 大模型服务
│   │   │   ├── ai_security.py             # AI 安全（脱敏/过滤）
│   │   │   ├── vector_store.py            # 向量库客户端（memory/qdrant/milvus）
│   │   │   ├── rag.py                     # RAG 检索
│   │   │   ├── push_service.py            # 推送服务（log/agc）
│   │   │   ├── obs.py                     # 对象存储（boto3 S3 兼容）
│   │   │   ├── sensitive.py               # 敏感词服务
│   │   │   └── security_service.py        # 安全服务
│   │   ├── tasks/                         # Celery 任务
│   │   │   ├── celery_app.py              # Celery 实例 + Beat 调度表
│   │   │   ├── jobs.py                    # 定时任务（自动收卷/统计聚合）
│   │   │   └── sync_db.py                 # 数据库同步任务
│   │   ├── db/
│   │   │   ├── session.py                 # async engine + SessionLocal
│   │   │   └── redis.py                   # Redis 连接池
│   │   └── seed.py                        # 种子数据生成
│   ├── alembic/                           # 数据库迁移
│   ├── alembic.ini                        # Alembic 配置
│   ├── scripts/
│   │   └── seed.py                        # 种子数据脚本
│   ├── tests/                             # 95 个 pytest 用例
│   ├── requirements.txt                   # Python 依赖（锁版本）
│   ├── Dockerfile                         # 后端容器构建
│   ├── .env.example                       # 环境变量模板
│   └── README.md                          # 后端说明
├── mysql/init/                            # MySQL 全量 DDL（自动初始化）
├── docs/
│   └── 交付说明.md                         # 账号表/接口总览/功能地图/已知限制
├── docker-compose.yml                     # 容器编排（mysql/redis/backend/worker/beat）
├── build-profile.json5                    # 项目构建配置（SDK 6.1.0 API 23）
├── hvigorfile.ts                          # 项目构建脚本
├── oh-package.json5                       # OpenHarmony 包配置
├── package.json                           # 项目元信息
└── 鸿蒙智学业.txt                          # 完整设计说明文档（V3.0）
```

## 技术栈

### 端侧（HarmonyOS NEXT）

| 组件 | 说明 |
|---|---|
| ArkTS + ArkUI | 声明式 UI 框架 |
| @ohos.net.http | HTTP 网络请求 |
| @ohos.router | 页面路由 |
| AppStorage | 全局状态管理 |
| Tabs 组件 | 底部导航（三角色 Tab） |
| ForEach | 列表渲染 |
| Progress | 进度条（学习进度/技能画像） |

### 后端（Python）

| 组件 | 版本 | 用途 |
|---|---|---|
| FastAPI | 0.115.6 | 异步 REST API、自动 OpenAPI 文档 |
| uvicorn[standard] | 0.32.1 | ASGI 服务器 |
| SQLAlchemy 2.0 (async) | 2.0.36 | ORM + Alembic 迁移 |
| aiosqlite / aiomysql | 0.20.0 / 0.2.0 | 数据库异步驱动 |
| Pydantic v2 | 2.10.3 | 请求/响应模型、配置管理 |
| Alembic | 1.14.0 | 表结构版本化迁移 |
| python-jose + passlib | 3.3.0 / 1.7.4 | JWT + BCrypt 认证 |
| redis-py (async) | 5.2.1 | 缓存/限流/黑名单 |
| Celery 5 | 5.4.0 | 异步任务（判分/聚合/推送） |
| pytest + pytest-asyncio | 8.3.4 / 0.25.0 | 单元测试与接口测试 |

## 数据库设计

库名 `smart_learn`，utf8mb4，InnoDB，共 40 张表，由 SQLAlchemy ORM 管理 + Alembic 迁移。

### 六域表概览

| 域 | 表 | 说明 |
|---|---|---|
| 用户域 | sys_user, sys_login_log, sys_audit_log, sys_config, sensitive_word | 用户、登录日志、审计日志、系统配置、敏感词 |
| 课程域 | course, chapter, section, resource, course_enrollment, course_skill_tag | 课程、章节、小节、资源、选课、技能标签映射 |
| 测评域 | knowledge_point, question, exam_paper, exam_paper_question, assignment, assignment_submission, exam, exam_record, exam_answer, wrong_question, student_kp_mastery | 知识点、题目、试卷、作业、考试、答题、错题、掌握度 |
| 就业域 | company, job_skill_tag, job_posting, student_profile, resume, job_application, job_favorite, career_event | 企业、技能标签字典、岗位、画像、简历、投递、收藏、招聘活动 |
| 服务域 | notification, notification_read, sign_task, sign_record, discussion_post, discussion_reply | 通知、签到、讨论 |
| AI/统计域 | ai_chat_log, study_plan, stat_daily_learning | AI 审计、学习计划、每日统计 |

### 核心数据关联链路

1. **测评 → 画像 → 就业**：exam_answer → student_kp_mastery → student_profile.skill_scores → 与 job_posting.skill_weights 加权匹配 → gap 标签反查 course_skill_tag → 补强课程推荐
2. **课程 → 测评**：section 学完 → 章节组卷 → exam/assignment 关联 chapter
3. **AI 追溯**：ai_chat_log.ref_type/ref_id 指向课程/岗位/错题，全量可审计

## 环境配置

### 前置依赖

| 依赖 | 最低版本 | 说明 |
|---|---|---|
| DevEco Studio | 5.0+ | HarmonyOS NEXT 开发 IDE |
| HarmonyOS SDK | API 23 (6.1.0) | 端侧编译 |
| Python | 3.11+ | 后端运行 |
| Docker + Docker Compose | 20.10+ / 2.20+ | 容器化部署（可选） |
| MySQL | 8.0+ | 生产数据库 |
| Redis | 7.0+ | 缓存/Celery Broker |

### 环境变量配置

后端通过 `.env` 文件管理配置，模板位于 `smartlearn-backend/.env.example`：

```bash
cp smartlearn-backend/.env.example smartlearn-backend/.env
```

#### 基础配置（必填）

| 变量名 | 默认值 | 说明 |
|---|---|---|
| `DATABASE_URL` | `sqlite+aiosqlite:///./smartlearn.db` | 数据库连接串。开发用 SQLite，生产切换 MySQL：`mysql+aiomysql://smartlearn:smartlearn_dev@127.0.0.1:3306/smart_learn` |
| `JWT_SECRET` | `change-me-in-production` | JWT 签名密钥，**生产环境务必更换** |
| `JWT_ALGORITHM` | `HS256` | JWT 算法 |
| `ACCESS_TOKEN_EXPIRE_MINUTES` | `60` | Access Token 过期时间（分钟） |
| `REFRESH_TOKEN_EXPIRE_DAYS` | `7` | Refresh Token 过期时间（天） |
| `CORS_ORIGINS` | `*` | CORS 允许源（生产环境建议限制） |

#### Redis 与 Celery 配置

| 变量名 | 默认值 | 说明 |
|---|---|---|
| `REDIS_URL` | 空 | Redis 连接串，例：`redis://127.0.0.1:6379/0` |
| `CELERY_BROKER_URL` | `memory://` | Celery Broker，生产用 `redis://127.0.0.1:6379/1` |
| `CELERY_BACKEND_URL` | `cache+memory://` | Celery 结果后端，生产用 `redis://127.0.0.1:6379/2` |
| `CELERY_ALWAYS_EAGER` | `true` | 开发模式下 Celery 同步执行 |

#### AI 与大模型配置

| 变量名 | 默认值 | 说明 |
|---|---|---|
| `LLM_API_KEY` | 空 | 大模型 API Key（OpenAI 兼容：GLM/Qwen） |
| `LLM_BASE_URL` | `https://api.openai.com/v1` | 大模型 API 地址 |
| `LLM_MODEL` | `gpt-4o-mini` | 模型名称 |
| `AI_REQUESTS_PER_MINUTE` | `10` | AI 每分钟限流次数 |
| `AI_DAILY_LIMIT` | `200` | AI 每日限额 |

#### 对象存储（OBS）配置

| 变量名 | 默认值 | 说明 |
|---|---|---|
| `OBS_AK` | 空 | 对象存储 Access Key |
| `OBS_SK` | 空 | 对象存储 Secret Key |
| `OBS_BUCKET` | 空 | 桶名 |
| `OBS_ENDPOINT` | 空 | 端点地址 |

未配置时行为：`POST /resources/upload-token` 返回 `storage=local`，使用本地存储回退。

#### 向量库（RAG）配置

| 变量名 | 默认值 | 说明 |
|---|---|---|
| `VECTOR_BACKEND` | `memory` | 向量库后端：`memory`（关键词检索兜底）/ `qdrant` / `milvus` |
| `QDRANT_URL` | 空 | Qdrant 服务地址 |
| `QDRANT_COLLECTION` | `smartlearn_kb` | Collection 名称 |
| `EMBEDDING_API_KEY` | 空 | Embedding API Key |
| `EMBEDDING_BASE_URL` | 空 | Embedding API 地址 |
| `EMBEDDING_MODEL` | `bge-large-zh` | Embedding 模型名称 |

#### 推送（Push Kit）配置

| 变量名 | 默认值 | 说明 |
|---|---|---|
| `PUSH_BACKEND` | `log` | 推送后端：`log`（占位日志）/ `agc`（华为 AGC） |
| `AGC_CLIENT_ID` | 空 | AGC 客户端 ID |
| `AGC_CLIENT_SECRET` | 空 | AGC 客户端密钥 |
| `AGC_TOKEN_URL` | `https://oauth-login.cloud.huawei.com/oauth2/v3/token` | AGC OAuth Token URL |
| `AGC_PUSH_URL` | `https://push-api.cloud.huawei.com/v1/{app_id}/messages:send` | AGC 推送 URL |
| `AGC_APP_ID` | 空 | AGC 应用 ID |

#### 其他配置

| 变量名 | 默认值 | 说明 |
|---|---|---|
| `EXAM_DURATION_MINUTES` | `60` | 考试默认时长 |
| `MYSQL_DATABASE` | `smart_learn` | Docker Compose MySQL 数据库名 |
| `MYSQL_USER` | `smartlearn` | Docker Compose MySQL 用户 |
| `MYSQL_PASSWORD` | `smartlearn_dev` | Docker Compose MySQL 密码 |
| `MYSQL_ROOT_PASSWORD` | `root_dev_password` | Docker Compose MySQL Root 密码 |
| `MYSQL_PORT` | `3306` | Docker Compose MySQL 端口 |
| `REDIS_PORT` | `6379` | Docker Compose Redis 端口 |
| `BACKEND_PORT` | `8000` | Docker Compose 后端端口 |

### 端侧 API 地址配置

端侧 API 基地址硬编码于 `entry/src/main/ets/common/ApiClient.ets`：

```typescript
private static readonly baseUrl: string = 'http://10.0.2.2:8000';
```

- 模拟器访问本机后端使用 `10.0.2.2`
- 真机调试时需改为本机局域网 IP（如 `http://192.168.1.100:8000`）
- 生产环境需改为 HTTPS 域名（鸿蒙网络请求强制 HTTPS）

## 运行指南

### 方式零：一键启动（推荐，MySQL 生产模式）

```powershell
cd smartlearn-backend
.\start_all.ps1          # 或直接双击 start_all.bat
```

一键脚本自动完成：**MySQL 服务检查/启动 → 建库（utf8mb4）→ ORM 建表 + 基础种子 →
SQLite 全量数据迁移（保留 ID 与外键）→ 真实数据补全 → FastAPI 启动**。

| 参数 | 默认 | 说明 |
|---|---|---|
| `-MysqlPassword` | `123456` | MySQL root 密码 |
| `-MysqlHost/-MysqlPort/-MysqlUser` | `127.0.0.1/3306/root` | 连接信息 |
| `-DbName` | `smartlearn` | 库名（utf8mb4） |
| `-BackendPort` | `8000` | 后端端口 |
| `-SkipMigrate` | - | MySQL 已有数据时跳过 SQLite 迁移 |
| `-SkipSeed` | - | 跳过真实数据补全 |

首次运行自动把 `DATABASE_URL` 写入 `.env`，之后手动 `uvicorn app.main:app` 也走 MySQL。
数据规模：47 张表 / 2838+ 行（29 用户、5 课程 158 小节、156 题、5 试卷 5 考试 51 份记录 507 条答题、
29 帖讨论、24 条私聊、40 签到任务、16 通知、11 反馈、85 进度、281 统计行）。

<details>
<summary>MySQL 手动部署（了解一键脚本内部步骤）</summary>

```powershell
# 1. 建库
mysql -uroot -p -e "CREATE DATABASE smartlearn DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci"

# 2. 连接串（写入 smartlearn-backend/.env）
DATABASE_URL=mysql+aiomysql://root:密码@127.0.0.1:3306/smartlearn?charset=utf8mb4

# 3. 建表 + 基础种子（幂等）
python -c "import asyncio; from app.database import init_db; asyncio.run(init_db())"

# 4. 从 SQLite 迁移全量数据（可选，保留自增 ID 与外键）
python migrate_to_mysql.py --db smartlearn --password 密码

# 5. 真实数据补全（幂等，SQLite/MySQL 双库自适应）
python seed_real_data.py

# 6. 启动
python -m uvicorn app.main:app --host 0.0.0.0 --port 8000
```
</details>

### 方式一：本地开发运行（SQLite，用于开发调试）

#### 1. 启动后端

```powershell
cd smartlearn-backend

# 创建虚拟环境
python -m venv .venv
.\.venv\Scripts\Activate.ps1

# 安装依赖
pip install -r requirements.txt

# 配置环境变量
Copy-Item .env.example .env
# 编辑 .env，按需填 DATABASE_URL / JWT_SECRET / REDIS_URL 等

# 启动服务
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

验证：
- 健康检查：`GET http://127.0.0.1:8000/health`
- API 文档：`http://127.0.0.1:8000/docs`

#### 2. 数据库初始化

```powershell
# 执行迁移（创建表结构）
alembic upgrade head

# 导入种子数据（幂等）
python scripts/seed.py
```

#### 3. 构建并运行端侧

确保已安装 DevEco Studio 并配置 HarmonyOS SDK API 23：

```powershell
# 设置环境变量
$env:DEVECO_SDK_HOME = "D:\HuaWei\DevEco Studio\sdk"
$env:JAVA_HOME      = "D:\HuaWei\DevEco Studio\jbr"
$env:PATH = "D:\HuaWei\DevEco Studio\jbr\bin;D:\HuaWei\DevEco Studio\tools\ohpm\bin;D:\HuaWei\DevEco Studio\tools\hvigor\bin;D:\HuaWei\DevEco Studio\tools\node;" + $env:PATH

# 安装依赖
ohpm install

# 构建 HAP
hvigorw --mode module -p module=entry@default assembleHap
```

产物位于：`entry/build/default/outputs/default/entry-default-unsigned.hap`

真机安装需在 DevEco Studio 配置签名后构建 `.app` 包。

#### 4. 使用 DevEco Studio 运行

1. 用 DevEco Studio 打开项目根目录
2. 连接 HarmonyOS 设备或启动模拟器
3. 点击 Run 或使用命令行：

```powershell
hdc install entry/build/default/outputs/default/entry-default-unsigned.hap
```

### 方式二：Docker Compose 运行（推荐用于生产部署）

#### 1. 配置环境变量

```bash
cp smartlearn-backend/.env.example .env
# 编辑 .env，填写生产值：
# - DATABASE_URL 改为 mysql+aiomysql://... 连接串
# - JWT_SECRET 更换为强随机密钥
# - REDIS_URL / CELERY_BROKER_URL 改为 redis://... 
# - CELERY_ALWAYS_EAGER=false
```

#### 2. 启动基础服务（MySQL + Redis）

```bash
docker compose up -d mysql redis
```

#### 3. 启动应用服务（后端 + Worker + Beat）

```bash
docker compose --profile app up -d
```

#### 4. 初始化数据库

```bash
docker compose exec backend alembic upgrade head
docker compose exec backend python scripts/seed.py
```

#### 5. 验证

- 健康检查：`GET http://127.0.0.1:8000/health`
- API 文档：`http://127.0.0.1:8000/docs`
- 集成状态：`GET /admin/integrations`（admin 权限）

### Docker Compose 服务说明

| 服务 | 镜像 | 端口 | 说明 |
|---|---|---|---|
| mysql | mysql:8.0 | 3306 | 数据库，自动执行 `mysql/init/` 下 DDL |
| redis | redis:7-alpine | 6379 | 缓存/Celery Broker |
| backend | 自建 Dockerfile | 8000 | FastAPI 应用（uvicorn） |
| worker | 自建 Dockerfile | - | Celery Worker（判分/聚合/推送） |
| beat | 自建 Dockerfile | - | Celery Beat（定时任务） |

## 演示账号

种子数据统一密码：`1015401x`（完整账号清单见 `种子数据说明.txt`）

| 角色 | 账号 | 密码 | 说明 |
|---|---|---|---|
| 管理员 | `admin` / `admin2` | `1015401x` | 数据大屏 / 审核 / 用户管理 |
| 教师 | `teacher1` ~ `teacher5` | `1015401x` | 授课 / 组卷 / 批改 / 学情统计 |
| 学生 | `student01` ~ `student20` | `1015401x` | student01 为全量数据演示账号 |

> 全部账号 `pwd_changed=1`（已完成初始改密），登录后直达对应角色首页。
> 登录支持**用户号**：`SL000003`（teacher1）/ `SL000008`（student01）等，与用户名等效。

### 真实数据规模（`seed_real_data.py` 生成，幂等可重跑）

| 域 | 规模 | 说明 |
|---|---|---|
| 用户 | 2 管理 + 6 教师 + 21 学生 | 统一密码 `1015401x`，用户号 SL000001~SL000029 |
| 课程题库 | 5 课程 × 27~41 题（共 156） | SINGLE/MULTI/JUDGE/BLANK/SHORT 五题型 × 3 难度 |
| 试卷考试 | 5 份试卷 / 5 场考试 | 每卷 10 题满分制，覆盖未开考/进行中/已结束三态 |
| 考试记录 | 51 份 + 507 条答题明细 | GRADED/GRADING 混合，含及格线判定与错题归集 |
| 错题本 | 172 条 | 按题 × 人生成，含错次与已掌握标记 |
| 课程讨论 | 24 帖 + 回复/点赞 | 覆盖 5 门课，与知识点联动 |
| 教师教研区 | 5 帖 + 回复 | 教学安排/试卷分析/教学法交流（学生不可见） |
| 讨论广场 | 全站 29 帖 | 支持 10/50/100 条分页演示（第 2 页可见） |
| 私聊 | 24 条 | 学生↔教师答疑、学生↔学生组队、教师↔教师教研三类对话流 |
| 签到 | 25 个任务 + 231 人次 | 近 3 天 5 门课 4 位码签到，含未签名单 |
| 通知 | 16 条（分角色） | 课程更新/成绩/宣讲会/维护/新岗位，部分已读 |
| 学习进度 | 85 条 | 每人每课 15%~100% 连续推进 |
| 每日统计 | 281 行（近 14 天） | USER 级分钟/题数/正确率 + COURSE 级活跃度 |

## 外部服务接入

| 服务 | 模块 | 配置 | 未配置时行为 |
|---|---|---|---|
| 对象存储 OBS | `app/services/obs.py` | `OBS_AK/OBS_SK/OBS_BUCKET/OBS_ENDPOINT` | `POST /resources/upload-token` 返回 `storage=local` |
| 向量库 RAG | `app/services/vector_store.py` | `VECTOR_BACKEND=memory/qdrant/milvus`、`QDRANT_URL`、`EMBEDDING_*` | 内存关键词检索兜底 |
| 推送 Push | `app/services/push_service.py` | `PUSH_BACKEND=log/agc`、`AGC_CLIENT_ID/SECRET/APP_ID` | `log` 占位，通知 `push_sent=1` |
| 大模型 LLM | `app/services/ai_service.py` | `LLM_API_KEY/LLM_BASE_URL/LLM_MODEL` | 8 场景规则引擎兜底（无密钥可用） |

集成状态探测：`GET /admin/integrations`（admin），返回 OBS / Push / RAG 三者的 `configured` / `reachable`。

## 真实数据生成

```bash
# 幂等脚本：可重复执行，已有数据自动跳过（内容指纹判重）
python seed_real_data.py        # 运行前自动提示备份 smartlearn.db.bak
```

生成器覆盖：考试域（试卷/记录/答题明细/错题）→ 讨论区（课程讨论 + 教师教研区）→
私聊（师生/同学/同事三类）→ 签到（近 3 天）→ 通知（分角色 + 已读状态）→
学习进度（课程级百分比自然推进）→ 每日学习统计（近 14 天 USER/COURSE 两级）。
同时清理测试残留：`course_id IS NULL` 的占位题、指向不存在考试的孤儿 `exam_record`。

## 测试

### 后端测试

```powershell
cd smartlearn-backend
pytest -q
```

预期结果：95 passed（19 个测试文件 / 95 个用例）

> 测试复用根目录 `smartlearn.db`（SQLite）。该文件若被历史导入残留污染，`test_admin_system.py::test_user_management_flow` 会因"账号已存在"失败——删库或换 `DATABASE_URL` 指向全新库后即恢复 95 passed。

### 数据库迁移验证

```powershell
alembic upgrade head   # 空库 → 40 表初始迁移通过
```

### 种子数据验证

```powershell
python scripts/seed.py  # 文档 13.4 规模（20 学生/5 课程/80 题/15 岗位）幂等写入
```

### 端侧构建验证

```powershell
hvigorw assembleHap     # BUILD SUCCESSFUL（unsigned HAP）
```

## API 概览

接口前缀 `/api/v1`，统一响应 `{code, message, data}`，`code=0` 成功。完整 OpenAPI 文档访问 `/docs`。

### 路由分组

| 路由文件 | 接口数 | 覆盖领域 |
|---|---|---|
| auth + users | 12 | 登录/登出/注册/改密/资料 |
| courses | 16 | 课程/章节/资源/进度 |
| assignments | 6 | 作业发布/提交/批改 |
| questions | 12 | 题库/AI 出题/试卷 |
| exams | 12 | 考试/答题/监控/判分 |
| wrong | 3 | 错题本/重练/掌握 |
| jobs + resumes + profile | 16 | 岗位/简历/画像/投递 |
| notify + sign + discussion | 12 | 通知/签到/讨论 |
| ai | 9 | 8 场景 AI + 反馈 |
| admin + stats | 10 | 用户管理/审核/日志/配置/大屏 |

### 错误码表

| code | HTTP | 含义 |
|---|---|---|
| 0 | 200 | 成功 |
| 1001/1002/1003 | 401/403/404 | 未登录/无权限/不存在 |
| 1004 | 423 | 账号锁定 |
| 2001 | 422 | 参数错误 |
| 3001/3002/3003/3004 | 410/409/429/409 | 已截止/考试状态冲突/切屏超限/重复操作 |
| 4001 | 403 | 内容未过审 |
| 5001/5002 | 503/200 | AI 不可用/AI 输出被拦截 |

## 已知限制

1. OBS / Push Kit / RAG 的真实后端联调需填对应凭据（代码与状态探测已就位）
2. 生产部署需补 Nginx + HTTPS（鸿蒙网络请求强制 HTTPS）
3. 视频播放/文档预览/资源上传端侧为占位页，真实播放/预览/直传需接 AVPlayer、文档渲染组件与 OBS 预签名直传
4. 交付材料（PPT、演示视频、Locust 压测报告、E-R 图）未产出

## 端侧 UI 验收状态

已在 HarmonyOS NEXT 模拟器（API 23, 1320×2856）完成真机级按钮级测试：

- **登录链路**：Splash → 登录页（深色渐变 + 玻璃卡 + 密码可见切换 + 记住我 + 醒目注册入口）→ 三角色首页
- **学生端**：课程/章节学习、错题本（9 题）与错题重练、作业列表（截止时间格式化）、笔记、AI 学习计划、搜索（课程 5/岗位 14）、消息中心点击进详情、退出登录
- **教师端**：组卷建考、作业批改（10 份提交/3 已批改）、考试监控、资源上传、课程编辑、学情统计（环形/雷达/柱状图）
- **管理端**：用户管理（27 人筛选）、企业管理（含待审核）、数据大屏（图表）、操作日志
- **稳定性**：登录态落盘，force-stop 重启免登录；登出后 token 清除验证通过

### V2.2 增量验收（联系人 + 签到 + 学情修复）

- **能力画像独立页**（学生「我的」→ 查看完整画像）：真实技能分雷达图 + 优势/待提升/薄弱分层条 + 环形综合分
- **我的课程**：5 门课完整课表（起止日期 2026-09-07→2027-01-10、上课时间、地点、考试时间、任课老师），点击展开/收起详情
- **好友/师生域**：唯一用户号（SL+6位，注册自动生成）搜索添加 → 申请/同意/拒绝（申请消息显示在消息 Tab）→ 列表（备注/最后消息/未读）→ 双向聊天（气泡 + 8s 轮询 + 已读状态）；学生/教师互加好友，教师用户码添加学生需同意，同课程师生自动关联；双方均可编辑备注名
- **课堂签到**：教师发起 4 位码（30s 倒计时 + 大号数字展示），学生「我要签到」页输入签到；授课页签到名单点击展开/再次点击收起（应到/已签/未签 + 补签/作废）
- **深浅色双向切换**：设置页原生 Toggle，四连击验证 246.1↔27.2 亮度完美交替（修复了 IBestCell builder 插槽渲染丢失与双事件竞态）
- **学情修复**：全库平均分（真实判分归一化）、题型正确率雷达（单选/多选/判断/填空/简答）、高频错题真实聚合次数、考试平均分按场展示，移除全部假数据公式

## 详细文档

- 完整设计说明：`鸿蒙智学业.txt`（V3.0，需求+架构+页面规格+模块设计+数据库+接口清单+AI 专项+部署+交付清单）
- 交付说明：`docs/交付说明.md`（账号表/接口总览/功能地图/已知限制）
- 种子数据说明：`种子数据说明.txt`（27 账号 + 关联数据全清单）
- 真实数据说明：`docs/真实数据说明.md`（seed_real_data.py 生成的数据全景/验证方法/重跑指南）
- MySQL 一键部署：`smartlearn-backend/start_all.ps1` / `start_all.bat`（建库→建表→迁移→启动全流程）
- 反馈中心：学生/教师「我的 → 设置 → 反馈中心」提交五类反馈并跟踪进度；管理端「控制台 → 快捷管理 → 反馈中心」按状态筛选处理（解决/驳回需填写回复）
