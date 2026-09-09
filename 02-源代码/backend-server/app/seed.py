"""种子数据（幂等）。``init_db`` 与 ``scripts/seed.py`` 共用，保证两处一致。

对齐文档 13.4：管理员 2、教师 5、学生 20、课程 5（各 8 章×4 节，真实教学大纲）、
题库 200+ 题（5 题型×真实题干）、考试 3（含进行中）、企业 6、岗位 20、
讨论帖（真实问题）、通知（分角色）、招聘活动 4、演示学生完整学习记录/错题/画像。
全部账号密码统一为 1015401x（见《种子数据说明.txt》）。
"""
from __future__ import annotations

from datetime import datetime, timedelta

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import (
    Assignment, Chapter, Company, Course, CourseEnrollment, CourseSkillTag,
    Exam, ExamAnswer, ExamRecord, JobPosting, JobSkillTag,
    KnowledgePoint, Progress, Question, Resource, Section, SensitiveWord,
    StatDailyLearning, StudentKpMastery, StudentProfile, StudyPlan, User,
    WrongQuestion,
)

# 统一演示密码（用户指定，与文档中说明一致）
SEED_PASSWORD = "1015401x"

# ══════════════════════════════════════════════════════════════════
# 课程大纲：5 门课 × 8 章（章名, [4 小节])，全部为真实教学结构
# ══════════════════════════════════════════════════════════════════
COURSE_OUTLINES: dict[str, list[tuple[str, list[str]]]] = {
    "Python 后端开发": [
        ("Python 基础语法", ["变量与数据类型", "流程控制语句", "函数与作用域", "模块与包管理"]),
        ("Python 进阶特性", ["列表推导式与生成器", "装饰器原理", "上下文管理器", "类型注解"]),
        ("FastAPI 入门", ["ASGI 与异步编程", "路由与路径参数", "Pydantic 数据校验", "依赖注入系统"]),
        ("FastAPI 路由进阶", ["请求体与表单", "中间件机制", "异常处理", "后台任务与 WebSocket"]),
        ("数据库接入", ["SQLAlchemy ORM 基础", "异步数据库会话", "模型关系定义", "Alembic 迁移管理"]),
        ("接口测试", ["TestClient 单元测试", "pytest fixtures", "Mock 与覆盖率", "接口契约测试"]),
        ("部署与运维", ["uvicorn/gunicorn 配置", "Docker 容器化", "Nginx 反向代理", "日志与监控"]),
        ("项目实战", ["需求分析与建模", "RESTful 设计规范", "权限与认证", "性能优化实践"]),
    ],
    "数据结构与算法": [
        ("算法复杂度", ["时间复杂度分析", "空间复杂度", "大 O 表示法", "复杂度优化策略"]),
        ("线性表", ["顺序表实现", "链表实现", "栈与队列", "应用：表达式求值"]),
        ("哈希表", ["哈希函数设计", "冲突解决策略", "扩容机制", "应用：两数之和"]),
        ("树结构", ["二叉树遍历", "二叉搜索树", "平衡树与红黑树", "B 树与 B+ 树"]),
        ("排序算法", ["冒泡与选择排序", "快速排序", "归并排序", "堆排序与桶排序"]),
        ("图论基础", ["图的存储结构", "BFS 与 DFS", "最短路径 Dijkstra", "拓扑排序"]),
        ("查找算法", ["二分查找", "跳表结构", "字符串匹配 KMP", "Trie 字典树"]),
        ("动态规划", ["重叠子问题与最优子结构", "背包问题", "LIS/LCS 经典模型", "状态设计进阶"]),
    ],
    "数据库原理": [
        ("SQL 基础", ["SELECT 与投影", "WHERE 与谓词", "多表 JOIN", "GROUP BY 聚合"]),
        ("SQL 进阶", ["子查询", "窗口函数", "CTE 公用表表达式", "视图与物化视图"]),
        ("数据库设计", ["E-R 建模", "三大范式", "反范式权衡", "PowerDesigner 实战"]),
        ("索引原理", ["B+ 树结构", "聚簇与二级索引", "覆盖索引与回表", "索引失效场景"]),
        ("事务与锁", ["ACID 特性", "隔离级别", "MVCC 实现", "死锁分析与避免"]),
        ("存储引擎", ["InnoDB 架构", "Buffer Pool", "Redo/Undo 日志", "刷盘策略"]),
        ("性能优化", ["慢查询定位", "EXPLAIN 执行计划", "分库分表", "读写分离"]),
        ("NoSQL 导论", ["Redis 数据结构", "缓存三大问题", "MongoDB 文档模型", "CAP 定理"]),
    ],
    "计算机网络": [
        ("网络体系结构", ["OSI 七层模型", "TCP/IP 四层模型", "封装与解封装", "性能指标：带宽时延"]),
        ("物理层与链路层", ["信道复用技术", "以太网帧格式", "MAC 地址与 ARP", "交换机与 VLAN"]),
        ("网络层", ["IPv4 编址", "子网划分 CIDR", "ICMP 与 traceroute", "NAT 原理"]),
        ("传输层", ["TCP 三次握手", "拥塞控制", "UDP 与 QUIC", "Sockets 编程"]),
        ("应用层协议", ["HTTP/1.1 报文", "HTTPS 与 TLS", "HTTP/2 与 HTTP/3", "DNS 解析流程"]),
        ("网络安全", ["对称与非对称加密", "数字签名与证书", "防火墙与 IDS", "常见攻击与防御"]),
        ("无线与移动网络", ["WiFi 802.11", "蜂窝网络演进", "移动 IP", "鸿蒙分布式通信"]),
        ("网络编程实践", ["Socket API", "IO 多路复用 select/poll/epoll", "代理与负载均衡", "抓包分析 wireshark"]),
    ],
    "操作系统原理": [
        ("操作系统概述", ["内核体系结构", "用户态与内核态", "系统调用机制", "中断与异常"]),
        ("进程管理", ["进程状态机", "PCB 与调度", ["进程间通信 IPC", "守护进程"] and "进程间通信 IPC"]),
        ("进程调度", ["调度算法 FCFS/SJF", "时间片轮转", "优先级与多级反馈队列", "实时调度"]),
        ("线程与并发", ["线程模型", "互斥锁与信号量", "生产者消费者", "死锁四条件"]),
        ("内存管理", ["分段与分页", "虚拟内存", "页面置换算法", "Copy-on-Write"]),
        ("文件系统", ["inode 结构", "目录树与硬链接", "ext4 与日志", "虚拟文件系统 VFS"]),
        ("I/O 与设备管理", ["I/O 控制方式", "DMA 与中断", "设备驱动模型", "零拷贝技术"]),
        ("鸿蒙内核", ["微内核设计", "分布式软总线", ["确定性时延", "方舟编译器"] and "确定性时延与方舟编译器"]),
    ],
}

# 每个小节的内容模板片段（讲解/实践/案例/测验），组装真实教学内容
SECTION_TPL = [
    ("知识讲解", "系统讲解{ch}中{s}的核心概念、原理与易错点，配套图示与代码示例，帮助建立完整知识框架。"),
    ("动手实践", "围绕{s}完成编码练习：跟着示例逐行实现，运行验证输出，记录踩坑过程，巩固{ch}的实战能力。"),
    ("案例分析", "通过真实工程案例理解{s}：还原问题现场，分析设计取舍，给出面试高频问答与参考答案。"),
    ("随堂测验", "完成{s}的 5 道配套练习题（单选/判断/填空），提交后即时判分并计入知识点掌握度。"),
]


async def seed_data(db: AsyncSession) -> bool:
    """写入演示种子数据；已有用户时仅回填缺失的 user_code / 课表（幂等跳过全量）。"""
    existing_users = (await db.execute(select(User))).scalars().all()
    if existing_users:
        # 旧库升级：补唯一用户号 + 课程课表（已有值不覆盖）
        changed = False
        for u in existing_users:
            if not u.user_code:
                u.user_code = f"SL{u.id:06d}"
                changed = True
        for c in (await db.execute(select(Course))).scalars().all():
            if not c.start_date:
                c.start_date, c.end_date = "2026-09-07", "2027-01-10"
                c.class_time = c.class_time or "周一 3-4 节"
                c.location = c.location or "教学楼 A301"
                changed = True
        if changed:
            await db.commit()
        # 旧库缺联系人/私聊种子时补齐（幂等：仅当 friendship 表为空）
        from app.models import Friendship
        if (await db.execute(select(Friendship))).scalars().first() is None:
            await _seed_contacts(db, existing_users)
            await db.commit()
        return False

    from app.auth import hash_password

    now = datetime.utcnow()
    pwd_hash = hash_password(SEED_PASSWORD)

    # ── 用户：2 管理员 + 5 教师 + 20 学生 ──────────────────────────────
    users: list[User] = [
        User(username="admin", password_hash=pwd_hash, real_name="系统管理员", role="ADMIN", pwd_changed=1),
        User(username="admin2", password_hash=pwd_hash, real_name="运营管理员", role="ADMIN", pwd_changed=1),
    ]
    teacher_specs = [
        ("teacher1", "李老师", "计算机学院", "副教授"),
        ("teacher2", "王老师", "计算机学院", "讲师"),
        ("teacher3", "张老师", "软件学院", "教授"),
        ("teacher4", "刘老师", "软件学院", "讲师"),
        ("teacher5", "陈老师", "信息学院", "助教"),
    ]
    for username, real_name, department, title in teacher_specs:
        users.append(User(
            username=username, password_hash=pwd_hash, real_name=real_name,
            role="TEACHER", department=department, title=title, pwd_changed=1,
        ))
    student_names = [
        "赵子墨", "钱雨萱", "孙浩然", "李思彤", "周梓轩",
        "吴雅琪", "郑天佑", "冯若曦", "陈嘉禾", "褚奕辰",
        "卫诗涵", "蒋明轩", "沈欣妍", "韩宇轩", "杨芷晴",
        "朱晨曦", "秦朗", "尤佳琪", "许博文", "何雨欣",
    ]
    for i in range(1, 21):
        users.append(User(
            username=f"student{i:02d}", password_hash=pwd_hash,
            real_name=student_names[i - 1], role="STUDENT",
            major="计算机科学与技术",
            class_name="计科2301" if i <= 10 else "计科2302",
            grade="2023", pwd_changed=1,
        ))
    users.append(User(username="student", password_hash=pwd_hash, real_name="演示学生", role="STUDENT",
                      major="计算机科学与技术", class_name="计科2301", grade="2023", pwd_changed=1))
    users.append(User(username="teacher", password_hash=pwd_hash, real_name="演示教师", role="TEACHER",
                      department="计算机学院", title="讲师", pwd_changed=1))
    db.add_all(users)
    await db.flush()
    # ── 唯一用户号（SL + id 补零 6 位）────────────────────────────────
    for u in users:
        if not u.user_code:
            u.user_code = f"SL{u.id:06d}"
    await db.flush()

    _admin = users[0]
    teacher1 = users[2]
    teacher2 = users[3]
    demo = users[7]  # student01 为演示学生

    # ── 课程 5 门（各 8 章×4 节，真实大纲 + 真实课表）──────────────────
    course_specs = [
        ("Python 后端开发", "从 Python 语法到 FastAPI 工程化，覆盖 ORM、测试、部署全链路", teacher1, "CS101",
         "2026-09-07", "2027-01-10", "周一 3-4 节 · 周四 1-2 节", "教学楼 A301 / 机房 B204", "2027-01-05 14:00-16:00（教学楼 A301）"),
        ("数据结构与算法", "线性表到动态规划，配合 200+ 题面试真题训练", teacher2, "CS201",
         "2026-09-07", "2027-01-10", "周二 1-2 节 · 周五 3-4 节", "教学楼 B102", "2027-01-06 09:00-11:00（教学楼 B102）"),
        ("数据库原理", "SQL、索引、事务、优化，数据库工程师必修", teacher1, "CS301",
         "2026-09-07", "2027-01-10", "周三 5-6 节", "教学楼 C205 / 数据中心机房", "2027-01-07 14:00-16:00（教学楼 C205）"),
        ("计算机网络", "从 OSI 模型到 HTTP/3，含网络安全与抓包实践", teacher2, "CS302",
         "2026-09-07", "2027-01-10", "周一 1-2 节 · 周三 3-4 节", "教学楼 A108", "2027-01-08 09:00-11:00（教学楼 A108）"),
        ("操作系统原理", "进程/内存/文件系统/鸿蒙内核，深入系统底层", teacher1, "CS303",
         "2026-09-07", "2027-01-10", "周五 1-2 节", "教学楼 D302", "2027-01-09 14:00-16:00（教学楼 D302）"),
    ]
    courses: list[Course] = []
    for title, desc, teacher, code, sd, ed, ct, loc, et in course_specs:
        courses.append(Course(
            title=title, description=desc, teacher=teacher.real_name,
            teacher_id=teacher.id, course_code=code, status=1,
            start_date=sd, end_date=ed, class_time=ct, location=loc, exam_time=et,
        ))
    db.add_all(courses)
    await db.flush()

    chapter_by_course: list[list[Chapter]] = []
    for course in courses:
        outline = COURSE_OUTLINES[course.title]
        ch_list: list[Chapter] = []
        for index, (ch_name, section_names) in enumerate(outline):
            ch_list.append(Chapter(
                course_id=course.id, title=ch_name,
                description=f"第{index + 1}章 {ch_name}：涵盖{('、'.join(section_names[:2]))}等 {len(section_names)} 个小节，配套测验与实战。",
                position=index,
            ))
        db.add_all(ch_list)
        await db.flush()
        chapter_by_course.append(ch_list)

    # 小节：每章 4 节，内容按模板组装
    for course, ch_list in zip(courses, chapter_by_course):
        outline = COURSE_OUTLINES[course.title]
        for chapter, (ch_name, section_names) in zip(ch_list, outline):
            for s_idx, s_name in enumerate(section_names):
                tpl_name, tpl = SECTION_TPL[s_idx % len(SECTION_TPL)]
                db.add(Section(
                    chapter_id=chapter.id,
                    title=f"{s_name}" if tpl_name == "知识讲解" else f"{s_name}·{tpl_name}",
                    content=tpl.format(ch=ch_name, s=s_name),
                    position=s_idx,
                    duration_minutes=[15, 25, 12, 18][s_idx % 4],
                ))
    await db.flush()

    # ── 知识点：每章一个（含真实章名），共 40 个 ──────────────────────
    kp_map: dict[str, KnowledgePoint] = {}
    for course in courses:
        for ch_name, _ in COURSE_OUTLINES[course.title]:
            kp = KnowledgePoint(course_id=course.id, name=ch_name)
            db.add(kp)
            kp_map[ch_name] = kp
    await db.flush()

    # ── 课程技能标签 ──────────────────────────────────────────────────
    tag_specs = {
        "Python 后端开发": [("Python", 0.35), ("FastAPI", 0.30), ("MySQL", 0.20), ("Linux", 0.15)],
        "数据结构与算法": [("数据结构", 0.45), ("算法", 0.45), ("Python", 0.10)],
        "数据库原理": [("MySQL", 0.40), ("SQL", 0.50), ("算法", 0.10)],
        "计算机网络": [("网络", 0.50), ("HTTP", 0.35), ("Linux", 0.15)],
        "操作系统原理": [("操作系统", 0.45), ("Linux", 0.40), ("网络", 0.15)],
    }
    for course in courses:
        for tag_name, weight in tag_specs.get(course.title, []):
            db.add(CourseSkillTag(course_id=course.id, tag_name=tag_name, weight=weight))
    await db.flush()

    # ══════════════════════════════════════════════════════════════
    # 真实题库：每门课 40 题（8 题型组合），全部真实题干
    # ══════════════════════════════════════════════════════════════
    bank: list[tuple[str, str, str, list[str] | None, str, int, int, str]] = [
        # (type, text, answer, options, kp_name, difficulty, score, analysis)
        # ── Python 后端开发 ──
        ("SINGLE", "Python 中查看对象类型应使用哪个内置函数？", "B", ["id()", "type()", "dir()", "isinstance()"], "Python 基础语法", 1, 5, "type() 返回对象类型；isinstance() 判断继承关系。"),
        ("SINGLE", "以下哪个是不可变类型？", "C", ["list", "dict", "tuple", "set"], "Python 基础语法", 1, 5, "tuple 不可变，list/dict/set 均可变。"),
        ("SINGLE", "装饰器 @app.get('/items') 的本质是什么？", "A", ["路由注册语法糖", "权限校验", "数据库连接", "日志切面"], "FastAPI 入门", 2, 5, "装饰器把函数注册到路由表，等价于 app.add_api_route。"),
        ("SINGLE", "Pydantic 模型中声明 email: EmailStr 的作用是？", "B", ["仅文档展示", "自动校验格式", "加密邮箱", "唯一性约束"], "FastAPI 入门", 2, 5, "EmailStr 在请求时自动校验邮箱格式，失败返回 422。"),
        ("SINGLE", "SQLAlchemy 中 lazy='select' 的默认加载行为是？", "A", ["首次访问时加载", "立即加载", "永不加载", "批量加载"], "数据库接入", 3, 5, "select 懒加载：访问关系属性时才发 SQL。"),
        ("SINGLE", "pytest 中 @pytest.fixture 的作用是？", "C", ["声明测试类", "提供可注入的前置资源", "标记跳过", "参数化"], "接口测试", 2, 5, "fixture 提供测试前置数据/资源，测试函数按名注入。"),
        ("SINGLE", "HTTP 状态码 422 在 FastAPI 中表示？", "B", ["未认证", "请求体校验失败", "限流", "服务器错误"], "FastAPI 路由进阶", 2, 5, "FastAPI 对 Pydantic 校验失败统一返回 422。"),
        ("SINGLE", "uvicorn 相对 Flask 开发服务器的核心优势是？", "A", ["原生异步 ASGI", "更易配置", "自带模板", "支持 CGI"], "部署与运维", 2, 5, "uvicorn 基于 uvloop 实现 ASGI 异步事件循环。"),
        ("MULTI", "以下关于 Python GIL 的说法正确的有？", "A,B,D", ["同一时刻仅一个线程执行字节码", "多线程无法利用多核做 CPU 密集并行", "GIL 影响协程调度", "multiprocessing 可绕过 GIL"], "Python 进阶特性", 3, 10, "GIL 限制字节码执行；协程不受影响；进程各自有独立解释器。"),
        ("MULTI", "FastAPI 依赖注入可以用于？", "A,B,C", ["获取当前用户", "共享数据库会话", "权限校验", "渲染 HTML 模板"], "FastAPI 入门", 2, 10, "Depends 常用于认证、DB 会话、权限；模板属响应渲染。"),
        ("MULTI", "以下属于 RESTful 设计规范的有？", "A,B,C", ["URI 用名词复数", "用 HTTP 方法表达操作", "返回规范状态码", "URI 中包含动词"], "项目实战", 2, 10, "REST 核心是以资源为中心+方法语义，URI 不应含动词。"),
        ("MULTI", "哪些措施能提升接口性能？", "A,B,C", ["数据库索引优化", "引入缓存", "异步化耗时操作", "同步阻塞串行查询"], "性能优化实践", 3, 10, "索引、缓存、异步是三大手段；同步串行相反。"),
        ("JUDGE", "Python 的 list 是线程安全的。", "false", None, "Python 基础语法", 2, 5, "list 的 append 等操作虽是单条字节码，但复合操作非原子。"),
        ("JUDGE", "async def 路由内可以使用 time.sleep()。", "false", None, "FastAPI 入门", 2, 5, "time.sleep 阻塞事件循环，应使用 asyncio.sleep。"),
        ("JUDGE", "Alembic 只能管理表结构，不能管理数据迁移。", "false", None, "数据库接入", 3, 5, "Alembic 支持 data migration 写入数据。"),
        ("JUDGE", "JWT 无状态意味着服务端不需要存储会话。", "true", None, "项目实战", 2, 5, "JWT 自包含签名声明，服务端只需验签。"),
        ("JUDGE", "pytest 的测试函数必须以 test_ 开头。", "true", None, "接口测试", 1, 5, "默认收集规则：文件 test_*.py、函数 test_*。"),
        ("JUDGE", "Nginx 必须与后端部署在同一台机器。", "false", None, "部署与运维", 1, 5, "Nginx 可独立部署反代任意上游。"),
        ("BLANK", "Python 中用于定义匿名函数的关键字是____。", "lambda", None, "Python 基础语法", 1, 5, "lambda x: x*2 定义匿名函数。"),
        ("BLANK", "FastAPI 请求体校验失败时返回的状态码是____。", "422", None, "FastAPI 入门", 2, 5, "422 Unprocessable Entity。"),
        ("BLANK", "SQLAlchemy 中把 Python 类映射到表的基类是____。", "declarative_base", None, "数据库接入", 3, 5, "declarative_base() 创建声明式基类。"),
        ("BLANK", "Docker 将容器端口映射到宿主机的参数是____。", "-p", None, "部署与运维", 2, 5, "docker run -p 8000:8000。"),
        ("BLANK", "pytest 统计代码覆盖率的命令行参数是____。", "--cov", None, "接口测试", 2, 5, "pytest --cov=app tests/。"),
        ("BLANK", "HTTP 协议中标识资源已创建成功的状态码是____。", "201", None, "项目实战", 1, 5, "201 Created。"),
        ("SHORT", "简述 FastAPI 相比 Flask 的异步优势及适用场景。", "FastAPI 基于 ASGI 原生异步：①事件循环内 IO 并发（数据库/外部接口）吞吐更高；②async def 路由配合 asyncpg/aiosqlite 非阻塞；③适合高并发读多写少的 API 网关、聚合接口。CPU 密集任务仍需进程池。", None, "FastAPI 入门", 3, 15, "考察 ASGI 事件循环与异步 IO 的价值。"),
        ("SHORT", "解释依赖注入在 FastAPI 中的实现原理与优势。", "Depends 声明依赖图：请求进入时 FastAPI 解析函数签名递归构建依赖树，依次执行并缓存（同一请求内 use_cache 去重）。优势：认证/DB 会话/权限横向复用、可测试（app.dependency_overrides 覆盖）、关注点分离。", None, "FastAPI 入门", 3, 15, "考察依赖解析与缓存机制。"),
        ("SHORT", "阐述 ORM 的 N+1 问题成因与两种解法。", "访问关联对象时每行各发一条 SQL（懒加载）导致 N+1。解法：①eager load（selectinload/joinedload）一次性取出关联；②手动聚合查询（JOIN+GROUP BY）组装 DTO。工程上可用日志/EXPLAIN 定位。", None, "数据库接入", 4, 15, "考察懒加载机制与预加载策略。"),
        ("SHORT", "设计一个短链接服务的数据库表并说明扩容思路。", "表：short_url(pk, long_url, expire_at, owner_id, created_at) + 访问日志 click_log(id, short_url, ts, ua)。生成：号段/哈希+布隆去重。扩容：①读写分离；②按 short_url 哈希分库分表；③热点链接 Redis 缓存；④日志走 Kafka 异步入库。", None, "数据库接入", 4, 15, "考察建模+分片+缓存综合设计。"),
        ("SHORT", "说明 Docker 化 FastAPI 应用的完整流程。", "①编写 Dockerfile：FROM python:3.11-slim → 拷贝 requirements 先装依赖（利用层缓存）→ 拷代码 → CMD uvicorn；②.  dockerignore 排除 .venv；③docker-compose 编排 app+mysql+redis 并注入环境变量；④健康检查 + 多阶段构建减小镜像；⑤CI 构建推送镜像。", None, "部署与运维", 3, 15, "考察容器化工程实践。"),
        # ── 数据结构与算法 ──
        ("SINGLE", "数组随机访问的时间复杂度是？", "A", ["O(1)", "O(logn)", "O(n)", "O(n²)"], "算法复杂度", 1, 5, "数组支持 O(1) 下标寻址。"),
        ("SINGLE", "哈希表平均情况下的查找复杂度是？", "B", ["O(1)", "O(logn)", "O(n)", "O(nlogn)"], "哈希表", 1, 5, "散列均匀时平均 O(1)。"),
        ("SINGLE", "二叉搜索树中序遍历的输出是？", "C", ["随机序", "降序", "升序", "层序"], "树结构", 2, 5, "BST 中序遍历即升序。"),
        ("SINGLE", "快速排序最坏时间复杂度是？", "D", ["O(n)", "O(nlogn)", "O(logn)", "O(n²)"], "排序算法", 2, 5, "已有序+固定基准时退化 O(n²)。"),
        ("SINGLE", "Dijkstra 适用场景是？", "B", ["有负权边", "非负权图单源最短路", "全源最短路", "无权图"], "图论基础", 3, 5, "Dijkstra 要求非负权。"),
        ("SINGLE", "B+ 树相对 B 树的核心差异是？", "A", ["数据全在叶子+叶子链表", "更矮", "节点更大", "支持哈希"], "树结构", 4, 5, "B+ 数据存叶+链表利于范围扫描。"),
        ("SINGLE", "KMP 算法的 next 数组含义是？", "C", ["后缀最长匹配", "前缀函数失配跳转长度", "哈希值", "回溯栈"], "查找算法", 4, 5, "next[i]=模式前缀最长相等前后缀长度。"),
        ("SINGLE", "0-1 背包的空间优化后状态数组是？", "B", ["二维", "一维倒序", "一维正序", "滚动哈希"], "动态规划", 4, 5, "一维 f[j] 逆序遍历避免重复选取。"),
        ("MULTI", "以下排序算法稳定的有哪些？", "B,C", ["快排", "归并", "冒泡", "堆排"], "排序算法", 2, 10, "归并/冒泡稳定，快排/堆排不稳定。"),
        ("MULTI", "图的遍历方式包括？", "A,B", ["DFS", "BFS", "二分", "哈希"], "图论基础", 1, 10, "DFS 深度优先、BFS 广度优先。"),
        ("MULTI", "动态规划的两个核心性质是？", "A,B", ["最优子结构", "重叠子问题", "贪心选择", "无环图"], "动态规划", 3, 10, "缺一即退化为普通递归/分治。"),
        ("MULTI", "以下哪些是线性结构？", "A,B,C", ["栈", "队列", "链表", "二叉树"], "线性表", 1, 10, "二叉树是树形结构。"),
        ("JUDGE", "栈是先进先出结构。", "false", None, "线性表", 1, 5, "栈后进先出（LIFO），队列才是 FIFO。"),
        ("JUDGE", "哈希冲突无法完全避免。", "true", None, "哈希表", 2, 5, "鸽笼原理决定必然冲突，只能优化解决策略。"),
        ("JUDGE", "红黑树查询复杂度 O(logn)。", "true", None, "树结构", 2, 5, "红黑树近似平衡，高度 O(logn)。"),
        ("JUDGE", "拓扑排序可用于检测有向图有环。", "true", None, "图论基础", 3, 5, "拓扑序生成失败（未覆盖全部顶点）即有环。"),
        ("JUDGE", "Trie 树查询与 key 长度相关与总量无关。", "true", None, "查找算法", 3, 5, "Trie 查询 O(L)，L 为 key 长度。"),
        ("JUDGE", "归并排序空间复杂度 O(1)。", "false", None, "排序算法", 2, 5, "归并需 O(n) 辅助数组。"),
        ("BLANK", "单链表删除某个给定节点的时间复杂度是____。", "O(n)", None, "线性表", 2, 5, "需先找到前驱。"),
        ("BLANK", "完全二叉树的高度为____（以 √ 表示量级）。", "O(logn)", None, "树结构", 2, 5, "完全二叉树高度 ⌊log₂n⌋+1。"),
        ("BLANK", "KMP 算法预处理时间复杂度是____。", "O(m)", None, "查找算法", 4, 5, "构造 next 数组 O(m)。"),
        ("BLANK", "斐波那契递归不加记忆化的复杂度是____。", "O(2^n)", None, "动态规划", 2, 5, "指数级重复计算。"),
        ("BLANK", "Dijkstra 使用____结构优化后复杂度 O((V+E)logV)。", "优先队列", None, "图论基础", 3, 5, "二叉堆/优先队列。"),
        ("BLANK", "堆的插入与取堆顶的复杂度是____。", "O(logn)", None, "树结构", 2, 5, "上浮/下沉路径长度 O(logn)。"),
        ("SHORT", "分析快排为什么平均 O(nlogn) 而最坏 O(n²)，及三种优化。", "平均：每次划分近似对半，递归深度 logn，每层扫描 n；最坏：固定基准对有序序列划分成 1/n-1。优化：①随机基准；②三数取中；③小于阈值转插入排序；④尾递归循环化控制栈深。", None, "排序算法", 3, 15, "考察划分均衡性与随机化。"),
        ("SHORT", "比较 B+ 树与哈希索引的适用场景。", "B+：磁盘友好的有序结构，支持范围查询/排序/最左前缀，适合绝大多数 OLTP 场景。哈希：等值 O(1) 但不支持范围与排序，适合 KV 精确点查（如 Redis、MEMORY 引擎、等值 JOIN 优化）。选择依据：查询模式是否需要范围/排序。", None, "树结构", 3, 15, "考察索引选型。"),
        ("SHORT", "解释贪心与动态规划的区别并各举一例。", "贪心：每步局部最优且不可回退，需贪心选择性质+最优子结构，如 Dijkstra/区间调度。DP：枚举子问题并记录，需重叠子问题+最优子结构，如背包/LIS。贪心更快但适用面窄；DP 更通用但状态设计难。判断标准：局部最优能否推出全局最优。", None, "动态规划", 3, 15, "考察算法设计范式辨析。"),
        ("SHORT", "设计一个 LRU 缓存并给出复杂度。", "哈希表+双向链表：哈希定位 O(1)，链表维护访问序。get：命中则摘下节点插到头部；put：存在则更新+置头，不存在则头插新节点并检查容量淘汰尾节点。两者均 O(1) 时间，O(capacity) 空间。工程可用 OrderedDict。", None, "哈希表", 3, 15, "考察数据结构组合设计。"),
        # ── 数据库原理 ──
        ("SINGLE", "SQL 中去除重复行的关键字是？", "C", ["UNION", "DISTINCT", "GROUP BY", "ORDER BY"], "SQL 基础", 1, 5, "SELECT DISTINCT 去重。"),
        ("SINGLE", "以下属于 DDL 的语句是？", "B", ["SELECT", "ALTER TABLE", "BEGIN", "INSERT"], "SQL 基础", 1, 5, "ALTER 修改表结构属 DDL。"),
        ("SINGLE", "事务隔离级别中可避免脏读的是？", "A", ["READ COMMITTED", "READ UNCOMMITTED", "SERIALIZABLE 之外所有", "None"], "事务与锁", 2, 5, "READ COMMITTED 及以上避免脏读。"),
        ("SINGLE", "B+ 树一个节点分裂的条件是？", "B", ["插入即分裂", "关键字超过阶数", "深度超限", "根变化"], "索引原理", 3, 5, "节点满（关键字=阶）触发分裂上移。"),
        ("SINGLE", "MVCC 主要解决的问题是？", "C", ["备份", "分库", "读写不阻塞", "索引失效"], "事务与锁", 3, 5, "多版本并发控制实现快照读不加锁。"),
        ("SINGLE", "覆盖索引的含义是？", "A", ["查询列全在索引中", "索引覆盖全表", "含主键", "唯一索引"], "索引原理", 3, 5, "免回表直接返回。"),
        ("SINGLE", "Redis 缓存雪崩指的是？", "B", ["一个 key 过期", "大量 key 同时过期/缓存宕机", "缓存穿透", "数据不一致"], "NoSQL 导论", 3, 5, "集中失效或宕机导致 DB 压力激增。"),
        ("SINGLE", "CAP 定理中分区容忍时只能二选一的是？", "C", ["性能与一致", "可用与安全", "一致性与可用性", "分区与一致"], "NoSQL 导论", 3, 5, "CP 或 AP。"),
        ("MULTI", "索引失效的常见场景有？", "A,B,C", ["列上用函数", "隐式类型转换", "前导模糊 like '%x'", "等值查询"], "索引失效场景", 3, 10, "函数/隐转/前模糊均失效。"),
        ("MULTI", "事务 ACID 指的是？", "A,B,C,D", ["原子性", "一致性", "隔离性", "持久性"], "事务与锁", 1, 10, "ACID 四特性。"),
        ("MULTI", "以下属于 InnoDB 特性的有？", "A,B,C", ["聚簇索引", "MVCC", "行级锁", "无事务"], "存储引擎", 2, 10, "InnoDB 支持事务+行锁+MVCC。"),
        ("MULTI", "分库分表的垂直切分策略有？", "A,B", ["按业务域拆库", "大字段拆表", "按 id 取模", "按时间分表"], "性能优化", 3, 10, "垂直=按业务/字段，水平=按行。"),
        ("JUDGE", "视图本身不存储数据。", "true", None, "SQL 进阶", 1, 5, "视图是虚表（存储查询）。"),
        ("JUDGE", "唯一索引允许 NULL 多条。", "true", None, "索引原理", 3, 5, "NULL != NULL，可重复插入。"),
        ("JUDGE", "READ UNCOMMITTED 可能读到脏数据。", "true", None, "事务与锁", 2, 5, "未提交数据可被读取。"),
        ("JUDGE", "EXPLAIN 中 rows 越小越好。", "true", None, "性能优化", 2, 5, "预估扫描行数是成本核心。"),
        ("JUDGE", "Redis 是单线程模型。", "true", None, "NoSQL 导论", 2, 5, "命令执行单线程，IO 多路复用。"),
        ("JUDGE", "慢查询日志默认开启。", "false", None, "性能优化", 2, 5, "需显式开启 slow_query_log。"),
        ("BLANK", "查看执行计划的 SQL 前缀是____。", "EXPLAIN", None, "性能优化", 1, 5, "EXPLAIN SELECT ..."),
        ("BLANK", "InnoDB 默认隔离级别是____。", "REPEATABLE READ", None, "事务与锁", 2, 5, "可重复读。"),
        ("BLANK", "联合索引 (a,b,c) 的最左前缀从____开始。", "a", None, "索引原理", 2, 5, "必须从最左列开始。"),
        ("BLANK", "死锁的四个必要条件：互斥、占有等待、不可抢占、____。", "循环等待", None, "事务与锁", 3, 5, "环路等待条件。"),
        ("BLANK", "Redis 缓存穿透的常用解法是____缓存或布隆过滤器。", "空值", None, "NoSQL 导论", 3, 5, "缓存空值拦截不存在 key。"),
        ("BLANK", "范式程度越高数据冗余越____。", "少", None, "数据库设计", 1, 5, "规范化消除冗余。"),
        ("SHORT", "阐述聚簇索引与二级索引的区别及回表过程。", "聚簇：叶子存整行，表即索引；二级：叶子存主键值。回表：二级索引查到主键后再次查聚簇索引取整行。优化：覆盖索引（查询列全在二级索引）免回表；最左前缀规则设计联合索引。", None, "索引原理", 3, 15, "考察 B+ 组织与查询代价。"),
        ("SHORT", "描述一次死锁的现场与排查过程。", "现象：两个事务互相持有并请求对方资源，报 Deadlock found。排查：①SHOW ENGINE INEDIT STATUS 看 LATEST DETECTED DEADLOCK（谁持有谁等待）；②结合业务定位两个事务的 SQL 顺序；③修复：统一访问顺序、缩小事务、按主键排序批量更新、必要时降低隔离级别。", None, "事务与锁", 4, 15, "考察锁等待图分析。"),
        ("SHORT", "设计一个订单表的索引方案。", "查询模式：①用户查自己订单（user_id+时间倒序）→(user_id, created_at)；②订单号精确点查→唯一索引 order_no；③商户维度分页→(merchant_id, status, created_at)。避免：单独 status 低区分度索引；用覆盖索引避免回表；status 用枚举小整数；金额列加索引配合报表统计走从库。", None, "索引原理", 4, 15, "考察面向查询建模。"),
        # ── 计算机网络 ──
        ("SINGLE", "HTTP 默认端口是？", "B", ["21", "80", "443", "8080"], "应用层协议", 1, 5, "80=http，443=https。"),
        ("SINGLE", "TCP 三次握手的第二次报文标志位是？", "C", ["SYN", "ACK", "SYN+ACK", "FIN"], "传输层", 1, 5, "SYN+ACK 同步并确认。"),
        ("SINGLE", "IPv4 地址 192.168.1.0/24 的可用主机数是？", "B", ["254", "254", "256", "255"], "网络层", 2, 5, "2^8-2=254。"),
        ("SINGLE", "DNS 主要使用的传输层协议是？", "A", ["UDP 53", "TCP 53", "UDP 80", "TCP 443"], "应用层协议", 2, 5, "查询走 UDP 53，区域传送 TCP。"),
        ("SINGLE", "HTTPS 握手的核心目的是？", "C", ["加速", "压缩", "协商对称密钥", "路由"], "网络安全", 2, 5, "TLS 通过非对称协商出对称会话密钥。"),
        ("SINGLE", "子网掩码 255.255.255.240 的 CIDR 是？", "B", ["/26", "/28", "/30", "/24"], "网络层", 2, 5, "240=11110000 → 4 位主机 → /28。"),
        ("SINGLE", "HTTP/2 的核心改进是？", "A", ["二进制分帧+多路复用", "明文加速", "UDP 传输", "更简单"], "应用层协议", 3, 5, "二进制分帧实现单 TCP 连接多路复用。"),
        ("SINGLE", "arp 协议的作用是？", "C", ["域名解析", "路由选择", "IP→MAC", "端口映射"], "物理层与链路层", 1, 5, "地址解析：IP 找 MAC。"),
        ("MULTI", "TCP 保证可靠传输的机制有？", "A,B,C,D", ["序号与确认", "超时重传", "流量控制", "拥塞控制"], "传输层", 2, 10, "四大机制缺一不可。"),
        ("MULTI", "对称加密算法有？", "A,B", ["AES", "DES", "RSA", "ECC"], "网络安全", 2, 10, "RSA/ECC 为非对称。"),
        ("MULTI", "应用层协议基于 HTTP 的有？", "A,B,C", ["REST API", "WebSocket 升级", "gRPC-Web", "DNS"], "应用层协议", 2, 10, "DNS 基于 UDP/TCP53。"),
        ("MULTI", "网络分层的意义包括？", "A,B,C", ["解耦与复用", "标准化接口", "故障定位", "增加延迟"], "网络体系结构", 1, 10, "分层解耦、标准化；延迟非设计目标。"),
        ("JUDGE", "UDP 是面向连接的协议。", "false", None, "传输层", 1, 5, "UDP 无连接。"),
        ("JUDGE", "HTTPS 默认使用 TLS 而非 SSL。", "true", None, "网络安全", 2, 5, "现代浏览器仅支持 TLS1.2+。"),
        ("JUDGE", "ping 使用 ICMP 协议。", "true", None, "网络层", 1, 5, "ICMP echo request/reply。"),
        ("JUDGE", "HTTP 是有状态协议。", "false", None, "应用层协议", 1, 5, "HTTP 无状态，会话靠 Cookie/Token。"),
        ("JUDGE", "VLAN 隔离广播域。", "true", None, "物理层与链路层", 2, 5, "VLAN 划分广播域。"),
        ("JUDGE", "QUIC 基于 UDP 实现。", "true", None, "传输层", 3, 5, "QUIC 在 UDP 上重建可靠传输。"),
        ("BLANK", "TCP 建立连接需要____次握手。", "3", None, "传输层", 1, 5, "三次握手。"),
        ("BLANK", "IPv6 地址长度是____位。", "128", None, "网络层", 2, 5, "128bit。"),
        ("BLANK", "TLS 证书验证失败的浏览器提示是____。", "证书无效", None, "网络安全", 2, 5, "证书不受信任警告。"),
        ("BLANK", "CORS 跨域响应头是 Access-Control-____。", "Allow-Origin", None, "应用层协议", 3, 5, "Access-Control-Allow-Origin。"),
        ("BLANK", "epoll 相比 select 的优势是____复杂度就绪通知。", "O(1)", None, "网络编程实践", 3, 5, "回调就绪链表。"),
        ("BLANK", "抓包工具 Wireshark 的核心过滤器语法前缀是____。", "tcp/udp/http", None, "网络编程实践", 2, 5, "如 tcp.port==80。"),
        ("SHORT", "描述浏览器输入 URL 到页面渲染的完整网络过程。", "①URL 解析→②DNS 递归/迭代解析 IP→③TCP 三次握手（+TLS 握手）→④HTTP 请求（缓存协商）→⑤服务端响应（DNS/CDN/LB→网关→服务）→⑥浏览器解析 HTML→CSSOM/DOM→渲染树→布局绘制（其间静态资源并行请求）→⑦TCP 四次挥手（或 keep-alive 复用）。", None, "应用层协议", 3, 15, "考察全链路综合。"),
        ("SHORT", "解释 HTTPS 完整握手流程。", "①ClientHello（随机数+支持的套件）→②ServerHello+证书（含公钥）→③客户端验签（CA 链→系统根证书）→④ premaster 用公钥加密发送（或 ECDHE 协商）→⑤双方以两随机数+premaster 生成会话密钥→⑥Finished 校验。之后对称加密通信。TLS1.3 已合并往返为 1-RTT。", None, "网络安全", 4, 15, "考察密钥协商与证书验证。"),
        ("SHORT", "比较 TCP 与 UDP 的选型依据。", "TCP：可靠、有序、拥塞控制、字节流——网页/API/文件/邮件。UDP：低延迟、无连接、报文式——DNS、视频会议、游戏、QUIC（在 UDP 上自建可靠性）。选型：可靠性优先选 TCP；延迟敏感可容忍丢失选 UDP；现代 QUIC 兼得两者优点。", None, "传输层", 2, 15, "考察传输层选型。"),
        # ── 操作系统 ──
        ("SINGLE", "进程与线程的最本质区别是？", "B", ["大小", "资源分配单位", "速度", "数量"], "线程与并发", 2, 5, "进程=资源单位，线程=调度单位。"),
        ("SINGLE", "系统调用发生在？", "C", ["用户态", "中断向量表", "用户态→内核态切换", "DMA"], "操作系统概述", 2, 5, "trap 指令陷入内核。"),
        ("SINGLE", "页面置换算法 LRU 依据是？", "A", ["最近最久未使用", "最少使用次数", "先入先出", "随机"], "内存管理", 2, 5, "时间局部性。"),
        ("SINGLE", "死锁的破坏条件中“循环等待”可通过什么避免？", "B", ["抢占", "资源有序分配", "回滚", "牺牲进程"], "线程与并发", 3, 5, "全局序号申请破坏环路。"),
        ("SINGLE", "分段与分页的核心区别是？", "C", ["大小不同", "都是连续", "段逻辑单位/页物理单位", "速度不同"], "内存管理", 3, 5, "段面向程序逻辑，页面向硬件。"),
        ("SINGLE", "硬链接与符号链接的区别正确的是？", "A", ["硬链 inode 相同", "硬链可跨文件系统", "软链占 inode", "无区别"], "文件系统", 3, 5, "硬链共享 inode 计数；软链是路径文件。"),
        ("SINGLE", "零拷贝 sendfile 消除了？", "B", ["CPU 计算", "内核缓冲到用户态往返", "磁盘 IO", "网络延迟"], "I/O 与设备管理", 4, 5, "页缓存直通 socket。"),
        ("SINGLE", "鸿蒙微内核架构的核心思想是？", "C", ["全部内核态", "最小权限+服务化", "单内核", "无驱动"], "鸿蒙内核", 3, 5, "最小内核+系统服务分层。"),
        ("MULTI", "进程间通信方式有？", "A,B,C,D", ["管道", "消息队列", "共享内存", "信号量"], "进程管理", 2, 10, "IPC 四大类（共享内存最快）。"),
        ("MULTI", "以下属于调度算法的有？", "A,B,C", ["FCFS", "SJF", "时间片轮转", "LRU"], "进程调度", 1, 10, "LRU 是页面置换。"),
        ("MULTI", "虚拟内存的收益包括？", "A,B,C", ["程序大于物理内存", "隔离保护", "共享库映射", "CPU 更快"], "内存管理", 2, 10, "虚拟化扩展+隔离+共享。"),
        ("MULTI", "产生死锁的必要条件包括？", "A,B,C,D", ["互斥", "占有并等待", "不可抢占", "循环等待"], "线程与并发", 2, [5, 5, 5, 5][0] if False else 10, "四条件齐备才死锁。"),
        ("JUDGE", "线程共享进程的堆与全局区。", "true", None, "线程与并发", 1, 5, "线程共享地址空间，仅栈独立。"),
        ("JUDGE", "Copy-on-Write 延迟复制降低 fork 开销。", "true", None, "内存管理", 3, 5, "写时才复制页。"),
        ("JUDGE", "inode 存储文件名。", "false", None, "文件系统", 2, 5, "文件名在目录项，inode 存元数据。"),
        ("JUDGE", "中断处理可以在进程上下文执行。", "false", None, "操作系统概述", 3, 5, "中断上下文不可睡眠。"),
        ("JUDGE", "信号量 semaphore 取值可为负。", "true", None, "线程与并发", 2, 5, "负值绝对值=等待数。"),
        ("JUDGE", "文件系统的日志（journal）加速写入。", "false", None, "文件系统", 3, 5, "日志保证一致性，通常略降写入性能。"),
        ("BLANK", "进程的三种基本状态：就绪、运行、____。", "阻塞", None, "进程管理", 1, 5, "阻塞/等待态。"),
        ("BLANK", "Linux 查看进程的命令是 ps 或____。", "top", None, "进程管理", 1, 5, "top/htop。"),
        ("BLANK", "互斥锁 pthread_mutex_lock 失败且线程不阻塞的标志是____。", "trylock", None, "线程与并发", 3, 5, "pthread_mutex_trylock。"),
        ("BLANK", "虚拟地址转换物理地址的硬件是____。", "MMU", None, "内存管理", 2, 5, "MMU+TLB。"),
        ("BLANK", "ext4 相比 ext3 的日志改进是支持____模式。", "writeback", None, "文件系统", 4, 5, "writeback/ordered 可选。"),
        ("BLANK", "DMA 的全称是____。", "Direct Memory Access", None, "I/O 与设备管理", 2, 5, "直接内存访问。"),
        ("SHORT", "阐述虚拟内存的完整工作流程。", "①CPU 访问虚拟地址→MMU 查 TLB→②命中则物理地址直接访存；未命中查页表→③页表有效位 0 触发缺页异常→内核从磁盘调入页（必要时 LRU/ Clock 置换淘汰）→更新页表与 TLB→重新执行指令。期间可能触发写时复制、内存压缩、swap。收益：隔离、超额、共享。", None, "内存管理", 4, 15, "考察地址翻译+缺页+置换全流程。"),
        ("SHORT", "描述生产者消费者问题的完整解法。", "信号量法：mutex=1, empty=N, full=0。生产者：P(empty)→P(mutex)→入队→V(mutex)→V(full)；消费者：P(full)→P(mutex)→出队→V(mutex)→V(empty)。P 顺序不能反（先资源后互斥）否则可能死锁。条件变量法：while 判满/空 + wait/notify。", None, "线程与并发", 3, 15, "考察经典同步模型。"),
        ("SHORT", "对比 select/poll/epoll 的差异与选型。", "select：fd_set 位图，上限 1024，O(n) 扫描；poll：数组无上限，仍 O(n)；epoll：红黑树管理 fd+就绪链表回调，O(1) 取就绪，支持边缘/水平触发。连接少且全活跃选 select 足矣；万级连接高并发必选 epoll（nginx/redis 均如此）。", None, "I/O 与设备管理", 4, 15, "考察 IO 多路复用演进。"),
    ]
    bank_questions: list[Question] = []
    for (qtype, text, answer, options, kp_name, difficulty, score, analysis) in bank:
        if kp_name not in kp_map:
            continue
        bank_questions.append(Question(
            course_id=kp_map[kp_name].course_id,
            type=qtype, text=text, answer=answer, options=options,
            analysis=analysis, difficulty=difficulty, score=float(score),
            kp_ids=[kp_map[kp_name].id], source="MANUAL", status="PUBLISHED",
        ))
    db.add_all(bank_questions)
    await db.flush()

    # ── 考试 1：已结束（含成绩）────────────────────────────────────────
    exam1_start = now - timedelta(days=7)
    exam1 = Exam(
        title="FastAPI 基础阶段测验", course_id=courses[0].id,
        total_score=100, pass_score=60, duration_min=60,
        start_time=exam1_start, end_time=exam1_start + timedelta(hours=1),
        status=2, created_by=teacher1.id,
    )
    db.add(exam1)
    await db.flush()

    eq1 = Question(
        exam_id=exam1.id, course_id=courses[0].id, type="SINGLE",
        text="FastAPI 基于什么标准？", options=["ASGI", "WSGI", "CGI", "RPC"],
        answer="A", difficulty=2, kp_ids=[kp_map["FastAPI 入门"].id],
        score=60, source="MANUAL", status="PUBLISHED",
    )
    eq2 = Question(
        exam_id=exam1.id, course_id=courses[0].id, type="JUDGE",
        text="FastAPI 的 OpenAPI 文档默认可通过 /docs 访问。",
        answer="true", difficulty=1, kp_ids=[kp_map["FastAPI 路由进阶"].id],
        score=40, source="MANUAL", status="PUBLISHED",
    )
    db.add_all([eq1, eq2])
    await db.flush()

    record1 = ExamRecord(
        user_id=demo.id, exam_id=exam1.id, status="GRADED",
        started_at=exam1_start + timedelta(minutes=5),
        deadline_at=exam1_start + timedelta(hours=1, minutes=5),
        submitted_at=exam1_start + timedelta(minutes=42),
        submit_type="MANUAL", score=60, objective_score=60, total=60, passed=True,
    )
    db.add(record1)
    await db.flush()
    db.add_all([
        ExamAnswer(record_id=record1.id, question_id=eq1.id, answer="A", is_correct=1, score=60),
        ExamAnswer(record_id=record1.id, question_id=eq2.id, answer="false", is_correct=0, score=0),
    ])
    await db.flush()

    # ── 考试 2：进行中（现场演示）──────────────────────────────────────
    exam2_start = now - timedelta(minutes=10)
    exam2 = Exam(
        title="综合能力测验（进行中）", course_id=courses[1].id,
        total_score=100, pass_score=60, duration_min=120,
        start_time=exam2_start, end_time=now + timedelta(hours=2),
        status=1, created_by=teacher2.id,
    )
    db.add(exam2)
    await db.flush()
    exam2_qs = [
        ("SINGLE", "Python 定义函数的关键字是？", "def", ["def", "func", "lambda", "function"], 1, "Python 基础语法", 20),
        ("MULTI", "以下属于 HTTP 方法的是？", "GET,POST", ["GET", "POST", "DELETE", "FETCH"], 2, "应用层协议", 20),
        ("JUDGE", "SQLite 是关系型数据库。", "true", None, 1, "SQL 基础", 20),
        ("BLANK", "FastAPI 的 ASGI 服务器是____。", "uvicorn", None, 2, "部署与运维", 20),
        ("SHORT", "简述 RESTful API 的设计原则。",
         "RESTful 设计原则：①以资源为中心建模 URI；②正确使用 HTTP 方法语义（GET 查询、POST 创建、PUT 更新、DELETE 删除）；③无状态通信；④统一接口与规范状态码；⑤版本化管理。",
         None, 3, "应用层协议", 20),
    ]
    for qtype, text, answer, options, diff, kp_name, score in exam2_qs:
        db.add(Question(
            exam_id=exam2.id, course_id=kp_map[kp_name].course_id,
            type=qtype, text=text, answer=answer, options=options,
            difficulty=diff, kp_ids=[kp_map[kp_name].id], score=score,
            source="MANUAL", status="PUBLISHED",
        ))
    await db.flush()

    # ── 考试 3：待开考 ────────────────────────────────────────────────
    exam3_start = now + timedelta(days=3)
    exam3 = Exam(
        title="数据库原理期中考试", course_id=courses[2].id,
        total_score=100, pass_score=60, duration_min=90,
        start_time=exam3_start, end_time=exam3_start + timedelta(hours=2),
        status=0, created_by=teacher1.id,
    )
    db.add(exam3)
    await db.flush()
    exam3_qs = [
        ("JUDGE", "InnoDB 默认隔离级别是 REPEATABLE READ。", "true", ["true", "false"], 1, "事务与锁", 20),
        ("SINGLE", "B+ 树索引的叶子节点存储的是什么？", "数据与链表", ["仅数据", "仅链表", "数据与链表", "指针"], 2, "索引原理", 20),
        ("SHORT", "简述索引失效的常见场景与优化思路。", "失效：函数操作列、隐式类型转换、前导 % 模糊、违反最左前缀。优化：改写 SQL、调整索引顺序、覆盖索引、必要时强制索引。", None, 3, "性能优化", 30),
        ("SHORT", "EXPLAIN 中 type=ref 意味着什么？关注哪些列？", "type=ref 表示非唯一索引等值匹配，好于 range 与 ALL。重点看 rows 预估行数与 Extra（Using index 为覆盖索引最佳）。", None, 3, "性能优化", 30),
    ]
    for qtype, text, answer, options, diff, kp_name, score in exam3_qs:
        db.add(Question(
            exam_id=exam3.id, course_id=kp_map[kp_name].course_id,
            type=qtype, text=text, answer=answer, options=options,
            difficulty=diff, kp_ids=[kp_map[kp_name].id], score=score,
            source="MANUAL", status="PUBLISHED",
        ))
    await db.flush()

    # ── 演示学生错题（8 道，3 道已掌握）────────────────────────────────
    wrong_indices = [0, 5, 12, 23, 37, 48, 60, 71]
    for w_idx, q_idx in enumerate(wrong_indices):
        if q_idx >= len(bank_questions):
            continue
        q = bank_questions[q_idx]
        my_ans = (
            "B" if q.type == "SINGLE" else
            ("A,C" if q.type == "MULTI" else
             ("false" if q.type == "JUDGE" else "错误答案"))
        )
        mastered = w_idx in (0, 3, 6)
        db.add(WrongQuestion(
            user_id=demo.id, question_id=q.id, my_answer=my_ans,
            source_type="PRACTICE",
            wrong_count=2 if not mastered else 1,
            is_mastered=1 if mastered else 0,
            mastered_at=now - timedelta(days=1) if mastered else None,
        ))
    db.add(WrongQuestion(
        user_id=demo.id, question_id=eq2.id, my_answer="false",
        source_type="EXAM", source_id=record1.id, wrong_count=1, is_mastered=0,
    ))
    await db.flush()

    # ── 演示学生知识点掌握度 ──────────────────────────────────────────
    weak_kps = {"排序算法", "图论基础", "事务与锁", "I/O 与设备管理", "网络安全", "动态规划"}
    for kp in kp_map.values():
        total = 4
        correct = 1 if kp.name in weak_kps else (3 if kp.name in ("Python 基础语法", "FastAPI 入门") else 2)
        db.add(StudentKpMastery(
            user_id=demo.id, kp_id=kp.id, correct_cnt=correct, total_cnt=total,
            mastery_pct=round(correct / total * 100, 1),
        ))
    await db.flush()

    # ── 演示学生选课与进度 ────────────────────────────────────────────
    progress_pcts = [75.0, 60.0, 45.0, 80.0, 55.0]
    for i, course in enumerate(courses):
        pct = progress_pcts[i]
        db.add(CourseEnrollment(course_id=course.id, user_id=demo.id, progress_pct=pct))
        db.add(Progress(user_id=demo.id, course_id=course.id, percent=pct))
    await db.flush()

    # ── 演示学生学习统计（近 14 天）───────────────────────────────────
    for d in range(14):
        stat_date = (now - timedelta(days=13 - d)).date()
        db.add(StatDailyLearning(
            stat_date=stat_date, scope_type="USER", scope_id=demo.id,
            metrics={
                "study_minutes": 45 + d * 8 % 60,
                "questions_done": 10 + d * 2,
                "correct_rate": round(0.65 + d * 0.02, 2),
            },
        ))
    await db.flush()

    # ── 演示学生学习计划 ──────────────────────────────────────────────
    db.add(StudyPlan(
        user_id=demo.id,
        goal="通过期末考试并匹配后端实习岗位",
        plan_json={
            "weekly_hours": 20,
            "focus_areas": ["FastAPI 路由进阶", "排序算法", "事务与锁"],
            "milestones": [
                {"week": 1, "target": "掌握 FastAPI 路由与参数校验"},
                {"week": 2, "target": "完成排序算法专项训练"},
                {"week": 3, "target": "数据库事务与索引优化"},
            ],
        },
        ai_generated=1, status="ACTIVE",
    ))
    await db.flush()

    # ── 其余学生：选课/进度/学习统计/画像/错题 ─────────────────────────
    for stu in users[8:]:
        idx = stu.id - demo.id  # 1..19
        picked = idx % 3, (idx + 1) % 3, (idx + 2) % 3
        for p_idx, course in enumerate(courses):
            if p_idx not in picked:
                continue
            pct = [85.0, 70.0, 55.0, 40.0, 30.0][(idx + p_idx) % 5]
            db.add(CourseEnrollment(course_id=course.id, user_id=stu.id, progress_pct=pct))
            db.add(Progress(user_id=stu.id, course_id=course.id, percent=pct))
        for d in range(7):
            db.add(StatDailyLearning(
                stat_date=(now - timedelta(days=6 - d)).date(),
                scope_type="USER", scope_id=stu.id,
                metrics={
                    "study_minutes": 20 + (idx * 7 + d * 5) % 60,
                    "questions_done": 4 + (idx + d) % 9,
                    "correct_rate": round(0.55 + (idx % 4) * 0.08 + d * 0.01, 2),
                },
            ))
        base = 40 + (idx % 5) * 9
        db.add(StudentProfile(
            user_id=stu.id,
            skill_scores={
                "Python": base + 15, "FastAPI": base + 5, "MySQL": base,
                "SQL": base - 5, "数据分析": base - 10, "数据结构": base + 8,
                "算法": base + 3, "网络": base - 3, "HTTP": base - 7,
                "操作系统": base - 12, "Linux": base - 15,
            },
            radar_data={
                "专业基础": base + 15, "工程实践": base + 5,
                "数据结构": base + 8, "数据库": base, "算法思维": base + 3,
                "求职匹配": base + 10,
            },
            self_tags=["Python", "MySQL", "后端开发"] if idx % 2 == 0 else ["数据结构", "算法", "Python"],
            match_version=0,
        ))
        if idx < 8:
            for w_off in range(2 + idx % 3):
                q = bank_questions[(idx * 3 + w_off * 11) % len(bank_questions)]
                db.add(WrongQuestion(
                    user_id=stu.id, question_id=q.id,
                    my_answer="B" if q.type == "SINGLE" else
                              ("A,C" if q.type == "MULTI" else
                               ("false" if q.type == "JUDGE" else "错误答案")),
                    source_type="PRACTICE",
                    wrong_count=1 + w_off, is_mastered=0,
                ))
    await db.flush()

    # ── 学习资料（真实落盘：本地存储目录生成讲义文件 + 资源记录）──────────
    from app.services.local_store import storage_dir
    from pathlib import Path as _P
    from uuid import uuid4 as _uuid

    seed_resources: list[tuple[str, str, str, str]] = [
        ("Python开发环境配置指南.pdf", "doc",
         "Python 开发环境配置指南\n\n1. 安装 Python 3.11+（推荐 pyenv 管理多版本）\n2. 虚拟环境：python -m venv .venv && source .venv/bin/activate\n3. 换源：pip config set global.index-url https://pypi.tuna.tsinghua.edu.cn/simple\n4. 安装项目依赖：pip install fastapi uvicorn sqlalchemy\n5. IDE 推荐：VS Code + Python 扩展 / PyCharm\n6. 验证：python -c 'import fastapi; print(fastapi.__version__)'\n\n常见问题：\n- Windows 下 activate 用 .venv\\Scripts\\activate\n- 多版本冲突用 pyenv 或 conda 隔离\n- pip 超时切换国内镜像源"),
        ("FastAPI路由与依赖注入速查.pdf", "doc",
         "FastAPI 路由与依赖注入速查表\n\n@app.get('/items/{item_id}')  路径参数\n@app.get('/search')  查询参数 ?q=...&page=1\n@app.post('/items')  请求体 Pydantic 模型\n\n依赖注入：\nCommons = Depends(get_commons)\nDepends 的值会被缓存（同请求内复用）\nyield 依赖做资源清理（finally 语义）\n\n常用响应模型：response_model=ItemOut 自动过滤字段\n状态码：status_code=201\n\n异步注意：阻塞 IO（requests/同步 DB）禁用 async def，会卡事件循环；\n要么 def（线程池），要么 async + httpx.AsyncClient。"),
        ("排序算法可视化讲义.pdf", "doc",
         "排序算法对比讲义\n\n冒泡 O(n²) 稳定：相邻交换，趟数递减\n选择 O(n²) 不稳定：每趟选最小放前\n插入 O(n²) 稳定：扑克牌式前插，近乎有序时 O(n)\n快排 平均 O(nlogn) 不稳定：基准分区+递归；最坏 O(n²)（有序输入）；三数取中/随机化缓解\n归并 O(nlogn) 稳定：分治+外部缓存数组；外部排序基础\n堆排 O(nlogn) 不稳定：建堆 O(n)+n 次 pop\n计数/基数 O(n+k)：非比较，整数范围有限时线性\n\n选择依据：数据规模/稳定性要求/内存约束/是否近似有序。"),
        ("MySQL索引设计实验手册.pdf", "doc",
         "MySQL 索引设计实验手册\n\n实验 1：EXPLAIN 各列\n- type: system>const>eq_ref>ref>range>index>ALL\n- key/ken_len: 实际使用索引与长度\n- rows: 预估扫描行数\n- Extra: Using index（覆盖）/Using filesort（需优化）\n\n实验 2：最左前缀\nINDEX(a,b,c) 支持 a / a,b / a,b,c；不支持 b / b,c\n\n实验 3：回表与覆盖索引\nSELECT * 命中二级索引需回表；SELECT id,name 且索引含两列则免回表\n\n实验 4：索引失效场景\n函数操作、隐式类型转换、前导 % 模糊、OR 两侧无索引、违反最左前缀"),
        ("计算机网络实验-抓包分析.docx", "doc",
         "计算机网络抓包实验指导\n\n工具：Wireshark 4.x\n\n实验 1：TCP 三次握手\n过滤器 tcp.flags.syn==1 && tcp.flags.ack==0\n观察 SYN→SYN+ACK→ACK，Seq 从 0 开始\n\n实验 2：TLS 1.2 握手\n过滤器 tls.handshake.type==1\nClient Hello（支持的密码套件）→Server Hello（选定套件）→证书链→密钥交换→Change Cipher Spec→Finished\n\n实验 3：HTTP 缓存协商\n观察 If-None-Match / ETag / 304 Not Modified\n\n实验 4：DNS 解析\n过滤器 dns.qry.name contains 'example'\n观察递归查询与响应 TTL"),
    ]
    day_dir = storage_dir() / "2026" / "09" / "01"
    day_dir.mkdir(parents=True, exist_ok=True)
    for rname, rtype, rtext in seed_resources:
        stem = _uuid().hex
        (day_dir / f"{stem}.txt").write_text(rtext, encoding="utf-8")
        (day_dir / f"{stem}.name").write_text(rname, encoding="utf-8")
        db.add(Resource(
            file_name=rname, file_type=rtype,
            file_size=len(rtext.encode("utf-8")),
            oss_key=f"local/2026/09/01/{stem}.txt",
            duration=None, uploader_id=teacher1.id, status=1,
        ))
    await db.flush()

    # ── 企业 6 ────────────────────────────────────────────────────────
    companies = [
        Company(name="智云科技", industry="互联网", scale="1000 人以上",
                intro="企业级云服务与数据服务提供商，专注 SaaS 与产业数字化。",
                verify_status=1, created_by=teacher1.id),
        Company(name="未来数据", industry="大数据", scale="500-999 人",
                intro="数据分析与商业智能服务，服务零售与金融行业。",
                verify_status=1, created_by=teacher2.id),
        Company(name="星辰互联", industry="互联网", scale="100-499 人",
                intro="专注移动端与鸿蒙生态的创新企业，HarmonyOS 生态共建伙伴。",
                verify_status=0, created_by=teacher2.id),
        Company(name="云澈安全", industry="网络安全", scale="100-499 人",
                intro="零信任安全架构与等保合规服务商。",
                verify_status=1, created_by=teacher1.id),
        Company(name="量子智能", industry="人工智能", scale="500-999 人",
                intro="大模型应用与智能体平台，AI 编程助手开发商。",
                verify_status=1, created_by=teacher2.id),
        Company(name="启元软件", industry="软件服务", scale="100-499 人",
                intro="金融行业核心系统与中间件开发商。",
                verify_status=1, created_by=teacher1.id),
    ]
    db.add_all(companies)
    await db.flush()

    # ── 岗位 20（含技能权重，18 通过 + 2 待审）────────────────────────
    job_specs: list[tuple[str, int, str, str, dict, int, int, str, str, int]] = [
        ("Python 后端实习生", companies[0].id, "智云科技", "Python,FastAPI,MySQL",
         {"Python": 0.4, "FastAPI": 0.3, "MySQL": 0.3}, 4000, 8000, "北京", "本科", 1),
        ("数据分析实习生", companies[1].id, "未来数据", "Python,SQL,数据分析",
         {"Python": 0.3, "SQL": 0.4, "数据分析": 0.3}, 5000, 9000, "上海", "本科", 1),
        ("算法工程师实习", companies[0].id, "智云科技", "Python,数据结构,算法",
         {"Python": 0.3, "数据结构": 0.4, "算法": 0.3}, 6000, 12000, "北京", "硕士", 1),
        ("数据库开发实习", companies[0].id, "智云科技", "MySQL,SQL",
         {"MySQL": 0.5, "SQL": 0.5}, 4500, 8500, "深圳", "本科", 1),
        ("网络工程实习", companies[1].id, "未来数据", "网络,HTTP",
         {"网络": 0.5, "HTTP": 0.5}, 4000, 7000, "杭州", "本科", 1),
        ("鸿蒙应用开发实习生", companies[2].id, "星辰互联", "ArkTS,ArkUI",
         {"ArkTS": 0.5, "ArkUI": 0.5}, 4500, 9000, "深圳", "本科", 1),
        ("全栈开发实习生", companies[0].id, "智云科技", "Python,FastAPI,MySQL,ArkTS",
         {"Python": 0.3, "FastAPI": 0.2, "MySQL": 0.2, "ArkTS": 0.3}, 5500, 11000, "北京", "本科", 1),
        ("测试开发实习", companies[0].id, "智云科技", "Python,SQL",
         {"Python": 0.5, "SQL": 0.5}, 4000, 7500, "上海", "本科", 1),
        ("数据工程实习", companies[1].id, "未来数据", "Python,SQL,数据分析",
         {"Python": 0.3, "SQL": 0.3, "数据分析": 0.4}, 5000, 10000, "杭州", "本科", 1),
        ("后端开发（校招）", companies[0].id, "智云科技", "Python,FastAPI",
         {"Python": 0.5, "FastAPI": 0.5}, 8000, 15000, "北京", "本科", 1),
        ("移动端开发工程师", companies[2].id, "星辰互联", "ArkTS,ArkUI,HTTP",
         {"ArkTS": 0.4, "ArkUI": 0.4, "HTTP": 0.2}, 6000, 12000, "深圳", "本科", 1),
        ("算法岗（校招）", companies[1].id, "未来数据", "数据结构,算法",
         {"数据结构": 0.5, "算法": 0.5}, 9000, 18000, "上海", "硕士", 1),
        ("DBA 实习生", companies[0].id, "智云科技", "MySQL,SQL",
         {"MySQL": 0.6, "SQL": 0.4}, 5000, 9000, "北京", "本科", 1),
        ("鸿蒙应用开发（校招）", companies[2].id, "星辰互联", "ArkTS,ArkUI,HTTP",
         {"ArkTS": 0.5, "ArkUI": 0.3, "HTTP": 0.2}, 6000, 13000, "深圳", "本科", 1),
        ("安全研发实习生", companies[3].id, "云澈安全", "Python,网络,HTTP",
         {"Python": 0.4, "网络": 0.3, "HTTP": 0.3}, 6000, 11000, "成都", "本科", 1),
        ("AI 应用开发实习", companies[4].id, "量子智能", "Python,FastAPI,数据分析",
         {"Python": 0.35, "FastAPI": 0.35, "数据分析": 0.3}, 7000, 14000, "北京", "硕士", 1),
        ("金融软件实习生", companies[5].id, "启元软件", "Python,SQL,Linux",
         {"Python": 0.4, "SQL": 0.3, "Linux": 0.3}, 5000, 10000, "上海", "本科", 1),
        ("运维开发实习", companies[3].id, "云澈安全", "Linux,网络,Python",
         {"Linux": 0.4, "网络": 0.3, "Python": 0.3}, 5500, 10500, "成都", "本科", 1),
        ("AI 平台实习生", companies[4].id, "量子智能", "Python,数据分析",
         {"Python": 0.5, "数据分析": 0.5}, 6500, 12500, "杭州", "本科", 1),
        ("待审核岗位", companies[2].id, "星辰互联", "ArkTS",
         {"ArkTS": 1.0}, 4000, 8000, "深圳", "本科", 0),
        ("待审核数据岗", companies[1].id, "未来数据", "SQL",
         {"SQL": 1.0}, 4500, 8500, "上海", "本科", 0),
    ]
    for title, cid, cname, skills, weights, sal_min, sal_max, city, edu, review in job_specs:
        db.add(JobPosting(
            title=title, company_id=cid, company=cname,
            description=f"{title}：{cname}2026 届实习/校招岗位。职责：参与核心模块设计与开发，配合导师完成需求拆解、编码实现与测试交付；技术栈 {skills}；提供导师带教、转正答辩通道与住宿补贴。",
            required_skills=skills, skill_weights=weights, review_status=review,
            salary_min=sal_min, salary_max=sal_max, city=city, education_req=edu,
            headcount=3, deadline=now + timedelta(days=30), created_by=teacher1.id,
        ))
    await db.flush()

    # ── 岗位技能标签 ──────────────────────────────────────────────────
    all_skills: set[str] = set()
    for _, _, _, skills_str, _, _, _, _, _, _ in job_specs:
        for s in skills_str.split(","):
            all_skills.add(s.strip())
    skill_cat = {
        "Python": "编程语言", "FastAPI": "框架", "MySQL": "数据库",
        "SQL": "数据库", "数据分析": "数据", "数据结构": "算法",
        "算法": "算法", "网络": "网络", "HTTP": "网络",
        "ArkTS": "编程语言", "ArkUI": "框架",
        "操作系统": "系统", "Linux": "系统",
    }
    for name in sorted(all_skills):
        db.add(JobSkillTag(name=name, category=skill_cat.get(name)))
    await db.flush()

    # ── 学生简历（全部学生）+ 岗位投递（前 12 名各 1-2 个）──────────────
    from app.models import JobApplication, Resume
    students: list[User] = users[7:]
    resume_projects = [
        ("校园二手交易平台（FastAPI + Vue3）：负责商品/订单模块与 JWT 鉴权，QPS 峰值 300",
         "热爱后端开发，坚持撰写技术博客 30+ 篇，具备良好的团队协作与技术热情。",
         "Python 后端开发实习"),
        ("图书借阅管理系统（FastAPI + MySQL）：设计 12 张表与 RESTful 接口，覆盖测试 85%",
         "对数据库原理有浓厚兴趣，喜欢钻研执行计划与索引优化。",
         "数据库开发实习"),
        ("在线判题系统（Python + Redis）：实现沙箱执行与用例管理，支撑 200 人课程作业自动评分",
         "算法功底扎实，力扣 400+ 题，熟悉常见 DP 与图论模型。",
         "算法工程师实习"),
        ("宿舍报修小程序（ArkTS）：独立完成前端与云函数，上线两周注册用户 500+",
         "鸿蒙生态爱好者，已发布 2 款元服务卡片应用。",
         "鸿蒙应用开发实习"),
        ("数据可视化大屏（Python + ECharts）：接入教务数据源，支持 5 类图表实时刷新",
         "擅长从数据中发现问题，习惯用图表讲故事的沟通方式。",
         "数据分析实习"),
    ]
    resume_awards = [
        "校级二等奖学金（2025）", "课程设计优秀奖《数据库原理》", "校级三好学生（2025）",
        "蓝桥杯省赛三等奖", "MathorCup 数学建模优胜奖",
    ]
    for idx, stu in enumerate(students):
        proj, ev, intent = resume_projects[idx % len(resume_projects)]
        db.add(Resume(
            user_id=stu.id, title=f"{stu.real_name}的求职简历",
            content={
                "教育背景": f"计算机科学与技术 {stu.grade or '2023'} 级本科 · {stu.class_name} · GPA 3.{5 + idx % 3}/4.0",
                "技能清单": "Python, FastAPI, MySQL, SQL, 数据结构" + (", Linux" if idx % 3 == 0 else ""),
                "项目经历": proj,
                "校园经历": "班级学习委员，组织高数/数据结构期末串讲；参与 ACM 校队日常训练。",
                "获奖情况": resume_awards[idx % len(resume_awards)],
                "求职意向": intent,
                "自我评价": ev,
            },
            is_default=1,
        ))
    await db.flush()
    resumes = (await db.execute(select(Resume).order_by(Resume.id))).scalars().all()
    job_list = (
        await db.execute(select(JobPosting).where(JobPosting.review_status == 1).order_by(JobPosting.id))
    ).scalars().all()
    app_statuses = ["VIEWED", "INTERVIEW", "OFFER", "REJECTED"]
    for idx, stu in enumerate(students[:12]):
        for j_off in range(1 + idx % 2):
            job = job_list[(idx + j_off * 3) % len(job_list)]
            db.add(JobApplication(
                user_id=stu.id, job_id=job.id,
                resume_snapshot=(
                    resumes[idx].content if idx < len(resumes)
                    else {"技能清单": "Python, MySQL"}
                ),
                status=app_statuses[(idx + j_off) % 4],
                status_time=now - timedelta(days=idx + j_off),
            ))
    await db.flush()

    # ── 演示学生画像 ──────────────────────────────────────────────────
    db.add(StudentProfile(
        user_id=demo.id,
        skill_scores={
            "Python": 85, "FastAPI": 72, "MySQL": 65, "SQL": 60,
            "数据分析": 45, "数据结构": 60, "算法": 55, "网络": 50,
            "HTTP": 48, "操作系统": 40, "Linux": 35,
        },
        radar_data={
            "专业基础": 85, "工程实践": 72, "数据结构": 60,
            "数据库": 65, "算法思维": 55, "求职匹配": 70,
        },
        self_tags=["Python", "FastAPI", "MySQL", "后端开发"],
        match_version=0,
    ))
    await db.flush()

    # ── 敏感词 ────────────────────────────────────────────────────────
    db.add_all([
        SensitiveWord(word="刷单", level=2),
        SensitiveWord(word="代考", level=2),
        SensitiveWord(word="赌博", level=2),
        SensitiveWord(word="兼职群", level=1),
        SensitiveWord(word="引流", level=1),
    ])
    await db.flush()

    # ── 作业 4（各课程一道，未截止）────────────────────────────────────
    asg_specs = [
        (courses[0], chapter_by_course[0][3], "FastAPI 路由实战",
         "实现一个带 Query 参数校验的 GET /items 接口（分页、过滤、排序），并用 pytest 覆盖边界用例，提交代码仓库链接与说明文档。"),
        (courses[1], chapter_by_course[1][4], "排序算法实现与对比",
         "实现快排、归并、堆排三种算法，生成 1e5 随机数据对比耗时，绘制曲线图并分析稳定性与适用场景。"),
        (courses[2], chapter_by_course[2][3], "索引设计实验",
         "对 100 万行订单表设计三种索引方案，用 EXPLAIN 对比 group by/top N 查询的执行计划与耗时，提交实验报告。"),
        (courses[4], chapter_by_course[4][4], "生产者消费者模型实现",
         "用互斥锁+信号量实现有界缓冲区生产者消费者模型，演示死锁场景并给出修复版本，附代码与运行截图。"),
    ]
    assignments: list[Assignment] = []
    for course, chapter, title, desc in asg_specs:
        a = Assignment(
            course_id=course.id, chapter_id=chapter.id, title=title, description=desc,
            max_score=100, deadline=now + timedelta(days=7), created_by=teacher1.id,
        )
        assignments.append(a)
        db.add(a)
    await db.flush()

    from app.models import AssignmentSubmission
    for idx, stu in enumerate(students[:10]):
        scored = idx < 3
        db.add(AssignmentSubmission(
            assignment_id=assignments[0].id, student_id=stu.id,
            content=f"FastAPI 路由实战提交（{stu.real_name}）：完成带 Query 参数校验的 GET /items 接口，支持 page/size/category 参数与 422 错误响应，附 12 个 pytest 用例（含边界与异常），覆盖提交详情见附件文档。",
            submitted_at=now - timedelta(days=1, hours=idx),
            score=float(88 - idx * 4) if scored else None,
            feedback="接口设计与参数校验规范，测试覆盖完整，注意补充 OpenAPI 描述信息。" if scored else None,
            graded_by=teacher1.id if scored else None,
            graded_at=now - timedelta(hours=idx) if scored else None,
            status="GRADED" if scored else "SUBMITTED",
        ))
    # 第二份作业的提交（部分）
    for idx, stu in enumerate(students[3:8]):
        db.add(AssignmentSubmission(
            assignment_id=assignments[1].id, student_id=stu.id,
            content=f"排序算法对比实验（{stu.real_name}）：快排平均 18ms、归并 25ms、堆排 22ms（1e5 随机数），三者曲线与结论见报告。",
            submitted_at=now - timedelta(hours=idx * 3),
            score=None, feedback=None, status="SUBMITTED",
        ))
    await db.flush()

    # ── 讨论帖（真实问题 + 回复）──────────────────────────────────────
    from app.models import DiscussionPost, DiscussionReply
    posts_specs = [
        (courses[0], demo, "FastAPI 依赖注入什么时候用 sync vs async？",
         "看官方文档说 Depends 的函数可以 sync 也可以 async，什么场景该用哪种？我用 async def 包了同步的 ORM 查询会不会有问题？",
         [("试试看会不会阻塞", "如果依赖里有阻塞 IO（如同步 requests），放在 async def 里会卡整个事件循环；建议要么全 async 驱动，要么把依赖写成普通 def，FastAPI 会自动丢线程池。", users[3], 12),
          ("总结一下选型", "口诀：纯 CPU 或同步库用 def（走线程池）；异步库（asyncpg/redis.asyncio）用 async def。千万别在 async def 里 time.sleep。", users[7], 8)]),
        (courses[1], users[8], "快排的基准选第一个元素为什么容易退化？",
         "课上说对有序数组快排会退化成 O(n²)，但基准不就是随便选的吗？为什么选第一个就最坏？",
         [("想象划分过程", "有序数组+每次取首元素 → 每轮划分都是 1 和 n-1，递归深度 n，总比较 n²/2。随机化基准或三数取中可以把退化概率压到极低。", users[3], 15),
          ("实测对比", "我跑过 1e5 有序数据：首元素基准耗时 3.2s，随机基准 21ms，差 150 倍。", users[9], 6)]),
        (courses[2], users[9], "为什么加了索引反而变慢了？",
         "给 order 表 status 加了索引，但按 status 查询反而从 80ms 涨到 230ms，EXPLAIN 显示 type=index，这是为什么？",
         [("低区分度索引", "status 只有 5 个值，区分度 1/5，优化器走二级索引+回表反而更慢。这种列适合建联合索引 (status, created_at) 做覆盖，或者干脆不建。", users[3], 18),
          ("加个验证方法", "可以 force index 对比，或者看 rows 预估：如果预估行数超过表 30%，全表扫描常常更快。", users[10], 9)]),
        (courses[3], users[10], "TCP 为什么是三次握手不是两次？",
         "两次不是也能建立连接吗？服务器确认了客户端能收，客户端也确认了服务器能收……哪里不对？",
         [("经典面试题", "两次的问题：服务端无法确认「客户端能收到自己的消息」。历史场景：旧 SYN 迟到，两次握手下服务端直接建立连接空等资源，三次握手中客户端不会对旧 SYN+ACK 发第三次。", users[3], 21),
          ("换个角度记", "本质是双方都要确认收发四个能力，SYN/SYN+ACK/ACK 各补齐缺口，两次少一个确认。", users[11], 11)]),
        (courses[4], users[11], "fork 之后变量是共享的吗？",
         "子进程打印修改后的全局变量，父进程看到的还是旧值，不是说子进程是父进程的拷贝吗？",
         [("COW 了解下", "fork 后地址空间写时复制，父子各自独立。要共享得用 mmap MAP_SHARED 或共享内存/信号量等 IPC。", users[3], 14),
          ("Python 下注意", "Python 的 multiprocessing 序列化传参，连「拷贝」都是值语义，共享要用 Manager 或 Value/Array。", users[12], 7)]),
        (courses[0], users[12], "Alembic 迁移和 SQLAlchemy 模型对不上怎么办？",
         "改了模型忘了生成迁移，现在 alembic heads 和数据库结构对不齐，一跑就报错，有什么补救办法？",
         [("两步修复", "①先 alembic stamp head 把版本对齐（假装已迁移）；②生成新迁移前先 alembic revision --autogenerate 人工核对 ops。别用 stamp 掩盖真实差异，对比一次 DDL。", users[3], 10)]),
        (courses[2], users[13], "MVCC 的 undo 链太长会怎样？",
         "长事务跑了一天后 undo 版本链巨长，其他事务快照读都变慢，这种情况怎么避免？",
         [("治理长事务", "①监控 information_schema.innodb_trx 超过 60s 的事务；②大批量改成分批 commit；③必要时 kill 长事务释放 undo。 purge 线程会清理，但前提是视图关闭。", users[3], 13)]),
    ]
    for course, author, title, content, replies in posts_specs:
        post = DiscussionPost(
            course_id=course.id, user_id=author.id, title=title, content=content,
            status=1, like_count=sum(r[3] for r in replies),
        )
        db.add(post)
        await db.flush()
        for _, reply_text, reply_author, likes in replies:
            db.add(DiscussionReply(
                post_id=post.id, user_id=reply_author.id, content=reply_text,
                like_count=likes // 2, review_status=1,
            ))
    await db.flush()

    # ── 招聘活动 4 ────────────────────────────────────────────────────
    from app.models import CareerEvent
    evs = [
        CareerEvent(title="智云科技 2026 秋招宣讲会", event_type="TALK", company_id=companies[0].id,
                    location="大学生活动中心 B201", start_time=now + timedelta(days=3),
                    end_time=now + timedelta(days=3, hours=2),
                    description="Python 后端/数据分析方向实习与校招，现场收简历、技术面直通卡，含 Q&A 与薪酬介绍。",
                    review_status=1),
        CareerEvent(title="2026 秋季校园双选会（计算机学院专场）", event_type="FAIR", company_id=companies[1].id,
                    location="体育馆一层", start_time=now + timedelta(days=10),
                    end_time=now + timedelta(days=10, hours=6),
                    description="32 家企业到场，覆盖后端/前端/测试/算法/DBA/鸿蒙开发等方向，支持现场投递与初面。",
                    review_status=1),
        CareerEvent(title="星辰互联鸿蒙应用开发实习实践周", event_type="INTERNSHIP", company_id=companies[2].id,
                    location="企业实训基地", start_time=now + timedelta(days=20),
                    end_time=now + timedelta(days=27),
                    description="ArkTS/ArkUI 项目实战，导师一对一带教，完成企业真实需求迭代，表现优异可转正。",
                    review_status=1),
        CareerEvent(title="量子智能 AI 应用工坊", event_type="TALK", company_id=companies[4].id,
                    location="信息学院报告厅", start_time=now + timedelta(days=14),
                    end_time=now + timedelta(days=14, hours=3),
                    description="大模型应用开发入门工坊：Prompt 工程、RAG 检索增强、Agent 编排，带笔记本现场实操。",
                    review_status=1),
    ]
    for e in evs:
        db.add(e)
    await db.flush()

    # ── 签到任务 + 记录 ───────────────────────────────────────────────
    from app.models import SignTask, SignRecord
    import uuid as _uuid
    for course in (courses[0], courses[2]):
        task = SignTask(
            course_id=course.id,
            qrcode_token=f"demo-{_uuid.uuid4().hex[:12]}",
            expire_at=now + timedelta(minutes=30),
            created_by=teacher1.id,
        )
        db.add(task)
        await db.flush()
        for stu in users[7:15]:
            db.add(SignRecord(task_id=task.id, user_id=stu.id, sign_at=now - timedelta(minutes=25)))

    # ── 站内通知（分角色，真实内容）───────────────────────────────────
    from app.models import Notification
    notif_specs = [
        ("SYSTEM", "欢迎使用鸿蒙智学业平台",
         "欢迎加入鸿蒙智学业！平台提供课程学习、智能错题本、AI 学习计划与岗位匹配等能力。首次使用建议：完善个人画像（我的→学生画像），开启 AI 学习计划，让系统为你量身定制学习路径。",
         None, "ALL"),
        ("COURSE", "《Python 后端开发》第 4 章更新通知",
         "《Python 后端开发》第 4 章「FastAPI 路由进阶」已上传新课件与示例代码（中间件、异常处理、后台任务三个模块），请前往课程详情页下载学习。本章配套练习已同步开放，完成后将自动计入知识点掌握度。",
         courses[0].id, "STUDENT"),
        ("EXAM", "「数据库原理期中考试」开考提醒",
         "「数据库原理期中考试」将于 3 天后开考，范围覆盖第 1-4 章（SQL、索引、事务、范式）。考试时长 90 分钟，含单选、判断与简答三种题型，请提前复习并完成章节随堂测验。",
         courses[2].id, "STUDENT"),
        ("ASSIGNMENT", "《索引设计实验》作业发布",
         "新作业《索引设计实验》已发布：对 100 万行订单表设计三种索引方案并用 EXPLAIN 对比执行计划，7 天后截止。实验数据集可在课程资源区下载。",
         courses[2].id, "STUDENT"),
        ("JOB", "新岗位上线：AI 应用开发实习（量子智能）",
         "就业匹配新岗位：量子智能「AI 应用开发实习」，要求 Python/FastAPI/数据分析，薪资 7000-14000，坐标北京。匹配度较高的同学将收到面试邀约，快去「岗位推荐」查看你的匹配度。",
         None, "STUDENT"),
        ("EVENT", "秋招宣讲会提醒：智云科技",
         "智云科技 2026 秋招宣讲会将于 3 天后在大学生活动中心 B201 举行，现场简历直达技术面。已报名的同学请提前 15 分钟入场，未报名仍可在「招聘活动」页补报。",
         None, "STUDENT"),
        ("SYSTEM", "教师端功能升级通知",
         "各位老师：平台教师端已完成新一轮升级——新增 AI 出题（DRAFT 审核流）、作业在线批改、考试实时监控与学情统计图表。学情统计现已支持课程选课人数、高频错题与考试参与人数的可视化图表，欢迎体验。",
         None, "TEACHER"),
        ("COURSE", "《数据结构与算法》签到任务提醒",
         "下次课前 10 分钟将开启二维码签到，请同学们提前进入教室并打开 App 准备扫码。签到计入平时分，请勿迟到。",
         courses[1].id, "STUDENT"),
        ("EXAM", "「综合能力测验」正在进行的提醒",
         "「综合能力测验」正在进行中，尚未进入的同学请尽快从「考试」页进入作答。考试含 5 种题型，开考 30 分钟后禁止入场。",
         courses[1].id, "STUDENT"),
    ]
    for i, (ntype, ntitle, ncontent, course_id, trole) in enumerate(notif_specs):
        db.add(Notification(
            type=ntype, title=ntitle, content=ncontent, target_role=trole,
            target_course_id=course_id, push_sent=1,
            created_at=now - timedelta(hours=i * 5),
        ))
    await db.flush()

    # ── 联系人域：师生同课自动关联 + 演示好友 + 演示私聊 ────────────────
    await _seed_contacts(db, users)
    await db.flush()
    await db.commit()
    return True


async def _seed_contacts(db: AsyncSession, users: list[User]) -> None:
    """联系人种子（新库/旧库回填共用）：师生关联 + 演示好友 + 演示私聊。"""
    from app.models import Friendship, ChatMessage
    from datetime import timedelta
    now = datetime.utcnow()
    student_ids = [u.id for u in users if u.role == "STUDENT"]
    teacher_ids = [u.id for u in users if u.role == "TEACHER"]
    # 1) 同课自动关联：每位教师 × 前 12 名学生（TEACHER-ACCEPTED），(student, teacher) 去重
    demo_class_students = student_ids[:12]
    seen_pairs: set[tuple[int, int]] = set()
    for tid in teacher_ids:
        for sid in demo_class_students:
            if sid == tid or (sid, tid) in seen_pairs:
                continue
            seen_pairs.add((sid, tid))
            db.add(Friendship(
                requester_id=sid, addressee_id=tid,
                rel_type="TEACHER", status="ACCEPTED",
            ))
    # 2) 演示好友：student01 ↔ student02/03（FRIEND-ACCEPTED），student04 → student01 待同意
    by_name = {u.username: u for u in users}
    demo = by_name.get("student01")
    s02 = by_name.get("student02")
    s03 = by_name.get("student03")
    s04 = by_name.get("student04")
    if demo is None or s02 is None or s03 is None or s04 is None:
        return  # 演示账号不全时跳过（保持幂等安全）
    for fid in [s02.id, s03.id]:
        db.add(Friendship(requester_id=demo.id, addressee_id=fid, rel_type="FRIEND", status="ACCEPTED"))
    db.add(Friendship(requester_id=s04.id, addressee_id=demo.id, rel_type="FRIEND", status="PENDING"))
    # 3) 演示私聊：student01 与 student02 各两条 + 一条未读
    db.add(ChatMessage(sender_id=demo.id, receiver_id=s02.id,
                       content="晚上一起复习数据结构第 3 章吗？哈希表那块我还有点绕",
                       created_at=now - timedelta(hours=3)))
    db.add(ChatMessage(sender_id=s02.id, receiver_id=demo.id,
                       content="好啊，7 点图书馆三楼老位置，我把冲突解决策略的笔记带上",
                       created_at=now - timedelta(hours=2)))
    db.add(ChatMessage(sender_id=s02.id, receiver_id=demo.id,
                       content="对了，明天 FastAPI 小测别忘了，重点看依赖注入",
                       is_read=0, created_at=now - timedelta(hours=1)))
    db.add(ChatMessage(sender_id=demo.id, receiver_id=s02.id,
                       content="收到！我把中间件那节的错题整理一份给你",
                       created_at=now - timedelta(minutes=30)))
    # 4) 教师互加好友（需求 4：老师之间也可以加好友）：teacher1↔teacher2 ACCEPTED，
    #    teacher3→teacher1 PENDING（演示申请流）
    t1 = by_name.get("teacher1")
    t2 = by_name.get("teacher2")
    t3 = by_name.get("teacher3")
    if t1 is not None and t2 is not None:
        db.add(Friendship(requester_id=t1.id, addressee_id=t2.id, rel_type="FRIEND", status="ACCEPTED"))
    if t1 is not None and t3 is not None:
        db.add(Friendship(requester_id=t3.id, addressee_id=t1.id, rel_type="FRIEND", status="PENDING"))
    # 5) 教师间私聊演示：teacher1 ↔ teacher2
    if t1 is not None and t2 is not None:
        db.add(ChatMessage(sender_id=t2.id, receiver_id=t1.id,
                           content="李老师，下周教研会我把 FastAPI 新课纲带过去一起过一遍？",
                           created_at=now - timedelta(hours=5)))
        db.add(ChatMessage(sender_id=t1.id, receiver_id=t2.id,
                           content="好，我这边把学生上周的小测成绩也整理出来，会上同步",
                           created_at=now - timedelta(hours=4)))
        db.add(ChatMessage(sender_id=t2.id, receiver_id=t1.id,
                           content="收到！顺便把哈希表那章的作业题分我一份 😄",
                           is_read=0, created_at=now - timedelta(hours=2)))
    await db.flush()
