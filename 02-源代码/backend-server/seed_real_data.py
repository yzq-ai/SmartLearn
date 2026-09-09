# -*- coding: utf-8 -*-
"""
真实数据生成器（幂等可重复执行，SQLite / MySQL 双库自适应）。

覆盖维度：
  1. 清理测试残留（course_id 为 NULL 的占位题、指向不存在考试的孤儿记录）
  2. 考试域：每门课一份真实试卷 exam_paper + 试卷题目；补齐各状态考试记录与答题明细
  3. 讨论区：补足课程讨论（覆盖 5 门课）+ 教师教研区帖子 + 学生回复/点赞（讨论广场分页演示）
  4. 私聊：学生↔学生、学生↔教师、教师↔教师 三类真实对话流
  5. 签到：近 3 天各课程签到任务 + 已签记录
  6. 通知：分角色通知（学生/教师/全部）+ 已读状态
  7. 学习进度：学生 × 选课的进度覆盖（复习模式，重算 percent）
  8. 每日学习统计：近 14 天 USER/COURSE 两级指标（分钟数/题数/正确率）
  9. 反馈中心：各状态真实反馈（待处理/处理中/已解决/已驳回）

数据库选择：优先读环境变量 DATABASE_URL / .env；默认回退 SQLite ./smartlearn.db。
幂等策略：以「内容指纹」为键（标题/日期+范围），存在即跳过；清理仅针对明确的测试残留。
"""
from __future__ import annotations

import os
import sys, io, json, random
from datetime import datetime, timedelta

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")

# ── 数据库选择：DATABASE_URL 优先，默认 SQLite ──
def _resolve_url() -> tuple[str, object]:
    """返回 (dialect, engine)。支持 sqlite+aiosqlite / mysql+aiomysql / mysql+pymysql。"""
    raw = os.environ.get("DATABASE_URL", "").strip()
    if not raw:
        env_file = os.path.join(os.path.dirname(os.path.abspath(__file__)), ".env")
        if os.path.exists(env_file):
            # utf-8-sig 兼容带 BOM 的 .env（否则 BOM 会混入 URL 值导致解析失败静默回退）
            for line in open(env_file, encoding="utf-8-sig"):
                line = line.strip()
                if line.startswith("DATABASE_URL="):
                    raw = line.split("=", 1)[1].strip()
                    break
    if not raw:
        raw = "sqlite:///./smartlearn.db"
    from sqlalchemy import create_engine
    from sqlalchemy.engine import make_url
    url = make_url(raw)
    dialect = url.drivername.split("+")[0]
    if dialect == "sqlite":
        # 注意：str(url) 会把密码渲染成 ***（脱敏），必须在原始字符串上替换驱动名
        sync_url = raw.replace("sqlite+aiosqlite", "sqlite")
    else:
        # mysql 异步驱动 → 同步 pymysql（同样在原始字符串上替换，保留真实密码）
        sync_url = raw.replace("mysql+aiomysql", "mysql+pymysql").replace("mysql+asyncmy", "mysql+pymysql")
    return dialect, create_engine(sync_url, future=True)


DIALECT, ENGINE = _resolve_url()
print(f"[db] dialect={DIALECT} url={ENGINE.url.render_as_string(hide_password=True)}")

random.seed(20260907)
now = datetime.now()

from sqlalchemy import text  # noqa: E402


class _Row(dict):
    """sqlite3 Row 风格 dict：支持 ['col'] 与 [int] 双下标。"""

    def __getitem__(self, key):
        if isinstance(key, int):
            return list(self.values())[key]
        return super().__getitem__(key)


class _ResultFacade:
    """sqlite3 Result 风格包装（fetchone/fetchall/keys），行返回 dict。"""

    def __init__(self, result):
        self._r = result
        try:
            self._cols = list(result.keys()) if result.returns_rows else []
        except Exception:  # noqa: BLE001
            self._cols = []
        self.rowcount = result.rowcount

    def _row(self, r) -> dict | None:
        return _Row(zip(self._cols, r)) if r is not None else None

    def fetchone(self):
        return self._row(self._r.fetchone())

    def fetchall(self):
        return [self._row(r) for r in self._r.fetchall()]

    def keys(self):
        return self._cols

    def __getitem__(self, idx):
        """兼容 result[0] 标量取值。"""
        row = self._r.fetchone()
        return row[idx] if row is not None else None

    def __iter__(self):
        return iter(self.fetchall())


_QMARK = __import__("re").compile(r"\?")


class _CurFacade:
    """sqlite3 Cursor 风格包装：execute(sql, params) 双方言兼容。

    - `?` 占位符自动转 SQLAlchemy `:p0, :p1, ...` 命名参数
    - INSERT OR IGNORE → MySQL 下转 INSERT IGNORE
    """

    def __init__(self, conn):
        self._conn = conn
        self.rowcount = 0
        self.lastrowid = 0

    @staticmethod
    def _convert(sql: str) -> str:
        sql2 = sql
        if DIALECT == "mysql":
            up = sql2.upper()
            # INSERT OR IGNORE / 末尾 ON CONFLICT DO NOTHING → MySQL INSERT IGNORE
            if up.startswith("INSERT OR IGNORE"):
                sql2 = "INSERT IGNORE" + sql2[len("INSERT OR IGNORE"):]
            elif up.rstrip().endswith("ON CONFLICT DO NOTHING"):
                sql2 = sql2.rstrip()[: -len("ON CONFLICT DO NOTHING")].rstrip()
                sql2 = sql2.replace("INSERT INTO", "INSERT IGNORE INTO", 1)
        # ? → :p0,:p1…（跳过字符串字面量内的 ?）
        out = []
        i = 0
        n = 0
        in_str = False
        while i < len(sql2):
            ch = sql2[i]
            if ch == "'":
                in_str = not in_str
                out.append(ch)
            elif ch == "?" and not in_str:
                out.append(f":p{n}")
                n += 1
            else:
                out.append(ch)
            i += 1
        return "".join(out)

    def execute(self, sql: str, params: tuple = ()):
        if params and not isinstance(params, (tuple, list)):
            params = (params,)
        named = dict()
        plist = list(params or ())
        for i, v in enumerate(plist):
            named[f"p{i}"] = v
        sql2 = self._convert(sql)
        res = self._conn.execute(text(sql2), named)
        self.rowcount = res.rowcount
        if DIALECT == "sqlite":
            self.lastrowid = res.lastrowid or 0
        else:
            self.lastrowid = self._conn.execute(text("SELECT LAST_INSERT_ID()")).scalar() or 0
        return _ResultFacade(res)

    def commit(self):
        self._conn.commit()

    def close(self):
        pass


_conn = ENGINE.connect()
cur = _CurFacade(_conn)
db = _conn  # 兼容旧名



def ts(d: datetime) -> str:
    return d.strftime("%Y-%m-%d %H:%M:%S.%f")


def days_ago(n: int, hour: int = 10, minute: int = 30) -> datetime:
    d = now - timedelta(days=n)
    d = d.replace(hour=hour, minute=minute, second=random.randint(0, 50), microsecond=random.randint(0, 999999))
    return d


# ═══════════════ 1. 清理测试残留 ═══════════════
removed_q = cur.execute(
    "DELETE FROM question WHERE course_id IS NULL AND (content LIKE '测试题%' OR content LIKE '关于「%')"
).rowcount
# 悬挂题目归属复位：exam_id 指向不存在的考试（UI 测试建考会偷挂题，考试被删后留悬挂）
removed_dang = cur.execute(
    "UPDATE question SET exam_id=NULL WHERE exam_id IS NOT NULL AND exam_id NOT IN (SELECT id FROM exam)"
).rowcount
# 孤儿考试记录（exam 已不存在的）
removed_r = cur.execute("DELETE FROM exam_record WHERE exam_id NOT IN (SELECT id FROM exam)").rowcount
# 无效考试防御：course 无效（含哨兵）且既无 question.exam_id 直挂、又无 paper 关联的考试
ghost_ids = [r[0] for r in cur.execute(
    "SELECT e.id FROM exam e "
    "WHERE (e.course_id IS NULL OR e.course_id = 0) "
    "   OR (NOT EXISTS (SELECT 1 FROM question q WHERE q.exam_id = e.id) "
    "       AND (e.paper_id IS NULL OR NOT EXISTS "
    "           (SELECT 1 FROM exam_paper_question pq WHERE pq.paper_id = e.paper_id)))"
).fetchall()]
removed_e = 0
for gid in ghost_ids:
    cur.execute("DELETE FROM exam_answer WHERE record_id IN (SELECT id FROM exam_record WHERE exam_id=?)", (gid,))
    cur.execute("DELETE FROM exam_record WHERE exam_id=?", (gid,))
    removed_e += cur.execute("DELETE FROM exam WHERE id=?", (gid,)).rowcount
print(f"[clean] 占位题 -{removed_q}，悬挂题归属 -{removed_dang}，孤儿考试记录 -{removed_r}，幽灵考试 -{removed_e}")

# ═══════════════ 基础映射 ═══════════════
# 排除教研区哨兵行（id=0，teacher_id 为空，不参与教学数据生成）
courses = {r["id"]: dict(r) for r in cur.execute("SELECT * FROM course") if r["id"] != 0}
teachers = [r["id"] for r in cur.execute("SELECT id FROM sys_user WHERE role_code='TEACHER'")]
students = [r["id"] for r in cur.execute("SELECT id FROM sys_user WHERE role_code='STUDENT'")]
print(f"[base] 课程 {len(courses)} 门，教师 {len(teachers)}，学生 {len(students)}")

# 每门课的题目（按难度取）
def pick_questions(course_id: int, n: int = 10):
    rows = list(cur.execute(
        "SELECT id, type, score, answer, options, content, difficulty FROM question "
        "WHERE course_id=? AND status='PUBLISHED' ORDER BY id", (course_id,)).fetchall())
    return rows[:n]


# ═══════════════ 2. 考试域：试卷 + 考试记录 + 答题明细 ═══════════════
# 2a. 为现有 3 场考试补真实试卷
paper_titles = {1: "FastAPI 基础阶段测验卷", 2: "数据结构综合能力测验卷", 3: "数据库原理期中试卷"}
for exam_id, title in paper_titles.items():
    exam = cur.execute("SELECT * FROM exam WHERE id=?", (exam_id,)).fetchone()
    if exam is None:
        continue
    if exam["paper_id"]:
        print(f"[paper] exam#{exam_id} 已有试卷，跳过")
        continue
    qs = pick_questions(exam["course_id"], 10)
    cur.execute(
        "INSERT INTO exam_paper (title, course_id, total_score, created_by, created_at) VALUES (?,?,?,?,?)",
        (title, exam["course_id"], sum(q["score"] for q in qs), exam["created_by"], ts(days_ago(14))))
    pid = cur.lastrowid
    total = 0
    for i, q in enumerate(qs):
        sc = q["score"]
        total += sc
        cur.execute(
            "INSERT INTO exam_paper_question (paper_id, question_id, score, sort_order) VALUES (?,?,?,?)",
            (pid, q["id"], sc, i + 1))
    cur.execute("UPDATE exam SET paper_id=?, total_score=? WHERE id=?", (pid, total, exam_id))
    print(f"[paper] exam#{exam_id} ← 试卷#{pid}（{len(qs)} 题 {total} 分）")

# 2b. 新增 2 场历史考试（已结束，供成绩分析演示）
extra_exams = [
    (4, 4, "计算机网络单元测验", 14, 2),   # course 4, 结束
    (5, 5, "操作系统原理阶段测验", 12, 2),  # course 5, 结束
]
for eid, cid, title, ago, status in extra_exams:
    if cur.execute("SELECT 1 FROM exam WHERE id=?", (eid,)).fetchone():
        continue
    qs = pick_questions(cid, 10)
    cur.execute(
        "INSERT INTO exam_paper (title, course_id, total_score, created_by, created_at) VALUES (?,?,?,?,?)",
        (f"{title}卷", cid, 100, courses[cid]["teacher_id"], ts(days_ago(ago))))
    pid = cur.lastrowid
    for i, q in enumerate(qs):
        cur.execute("INSERT INTO exam_paper_question (paper_id, question_id, score, sort_order) VALUES (?,?,?,?)",
                    (pid, q["id"], q["score"], i + 1))
    cur.execute(
        "INSERT INTO exam (id, course_id, paper_id, title, total_score, pass_score, duration_min, "
        "start_time, end_time, max_switch_cnt, show_score_mode, status, created_by) "
        "VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)",
        (eid, cid, pid, title, 100, 60, 45,
         ts(days_ago(ago, 9, 0)), ts(days_ago(ago, 10, 30)), 3, 1, status, courses[cid]["teacher_id"]))
    print(f"[exam] 新增 {title}（course {cid}）")

# 2c. 学生考试记录 + 答题明细（覆盖 GRADED / GRADING / 提交未判 3 态）
exam_ids = [1, 2, 3, 4, 5]
enroll = {}
for r in cur.execute("SELECT user_id, course_id FROM course_enrollment"):
    enroll.setdefault(r["course_id"], []).append(r["user_id"])

rec_created = 0
ans_created = 0
for eid in exam_ids:
    exam = cur.execute("SELECT * FROM exam WHERE id=?", (eid,)).fetchone()
    if exam is None:
        continue
    cid = exam["course_id"]
    # 该课学生（排除无选课的）
    roster = enroll.get(cid, students[:12])
    paper_qs = list(cur.execute(
        "SELECT q.id, q.type, q.score, q.answer, q.options FROM exam_paper_question pq "
        "JOIN question q ON q.id = pq.question_id WHERE pq.paper_id=? ORDER BY pq.sort_order",
        (exam["paper_id"],)).fetchall()) if exam["paper_id"] else []
    for uid in roster[:10]:
        # 已有记录则跳过
        if cur.execute("SELECT 1 FROM exam_record WHERE exam_id=? AND user_id=?", (eid, uid)).fetchone():
            continue
        # 成绩画像：3 档（优秀 85±/及格 68±/待提升 45±）
        band = random.random()
        base = 88 + random.uniform(-6, 8) if band < 0.3 else (70 + random.uniform(-8, 10) if band < 0.75 else 46 + random.uniform(-8, 12))
        status = "GRADED"
        started = days_ago(random.randint(1, 10), 9, random.randint(0, 59))
        submitted = started + timedelta(minutes=random.randint(25, 44))
        # 逐题作答
        objective = 0.0
        total = 0.0
        snap = {"questions": []}
        for i, q in enumerate(paper_qs):
            sc = q["score"]
            total += sc
            if q["type"] in ("SINGLE", "MULTI", "JUDGE", "BLANK"):
                p_correct = 0.55 + (base - 45) / 100.0 + random.uniform(-0.15, 0.15)
                correct = random.random() < min(0.96, max(0.1, p_correct))
            else:
                correct = None  # 主观题待批
            my = q["answer"]
            if not correct:
                opts = json.loads(q["options"]) if q["options"] else ["A", "B"]
                my = random.choice([o for o in opts if o != q["answer"]] or opts)
            got = sc if correct else (sc * 0.5 if correct is None and random.random() < 0.5 else 0.0)
            if q["type"] not in ("SINGLE", "MULTI", "JUDGE", "BLANK"):
                got = None  # 主观题分由 GRADING 决定
            if got:
                objective += got if q["type"] in ("SINGLE", "MULTI", "JUDGE", "BLANK") else 0
            snap["questions"].append({"id": q["id"], "score": sc})
        # 简化：主观题给一半分（模拟已批）
        has_subjective = any(q["type"] == "SHORT" for q in paper_qs)
        subjective_gain = sum(q["score"] * 0.6 for q in paper_qs if q["type"] == "SHORT")
        final = min(100.0, base)
        # 少数留 GRADING 态
        if random.random() < 0.12 and has_subjective:
            status = "GRADING"
            final = round(objective, 1)
        cur.execute(
            "INSERT INTO exam_record (user_id, exam_id, paper_snapshot, status, started_at, deadline_at, "
            "submitted_at, submit_type, score, objective_score, total, passed, switch_count, version) "
            "VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
            (uid, eid, json.dumps(snap, ensure_ascii=False), status, ts(started),
             ts(started + timedelta(minutes=exam["duration_min"] or 45)), ts(submitted), "MANUAL",
             final, round(objective, 1), total, 1 if final >= 60 else 0, random.randint(0, 2), 1))
        rid = cur.lastrowid
        rec_created += 1
        for i, q in enumerate(paper_qs):
            my = q["answer"]
            if random.random() < 0.4 and q["type"] in ("SINGLE", "JUDGE"):
                opts = json.loads(q["options"]) if q["options"] else ["A", "B"]
                wrong = [o for o in opts if o != q["answer"]]
                my = random.choice(wrong) if wrong else my
            got = q["score"] if my == q["answer"] else 0
            if q["type"] == "SHORT":
                got = None
            cur.execute(
                "INSERT INTO exam_answer (record_id, question_id, answer, is_correct, score, updated_at) "
                "VALUES (?,?,?,?,?,?)",
                (rid, q["id"], str(my), 1 if got else (None if got is None else 0), got, ts(submitted)))
            ans_created += 1
            # 错题入库
            if got == 0 and q["type"] in ("SINGLE", "MULTI", "JUDGE", "BLANK"):
                cur.execute(
                    "INSERT INTO wrong_question (user_id, question_id, my_answer, source_type, source_id, "
                    "wrong_count, is_mastered, created_at, updated_at) VALUES (?,?,?,?,?,?,?,?,?) "
                    "ON CONFLICT DO NOTHING",
                    (uid, q["id"], str(my), "EXAM", rid, random.randint(1, 3), random.random() < 0.2,
                     ts(submitted), ts(days_ago(0))))
print(f"[exam] 新增考试记录 {rec_created} 条，答题明细 {ans_created} 条，错题若干")

# ═══════════════ 3. 讨论区（含教研区 + 讨论广场）════════════════
# 课程讨论模板（每门课 2-4 帖，覆盖 5 门课 → 广场 25+ 帖满足 10/50/100 分页演示）
DISC = {
    1: [
        ("Pydantic 校验器和 ORM 模式怎么配合？", "在 SQLAlchemy 2.0 里用 mapped_column，再写 from_attributes 的 ConfigDict，但嵌套对象更新时总报错，大家的实践是？"),
        ("FastAPI 的 BackgroundTasks 和 Celery 怎么选？", "轻量任务（发通知、写日志）用 BackgroundTasks，重任务（导 Excel、爬虫）上 Celery。边界在哪？"),
        ("异步数据库连接池的坑", "asyncpg 连接池 max_size 设多少合理？高并发下偶现 TimeoutError。"),
    ],
    2: [
        ("时间复杂度怎么直觉判断？", "看到双层循环就 O(n²) 吗？有没有更快的判断方法？"),
        ("红黑树和 AVL 实际怎么选？", "数据库索引用 B+ 树而不是红黑树，查询场景差异在哪？"),
        ("图的最短路复习重点", "Dijkstra 和 Bellman-Ford 的适用条件总记混，有没有口诀？"),
        ("动态规划的入门套路", "从爬楼梯到背包，状态定义是关键，大家刷题顺序推荐？"),
    ],
    3: [
        ("EXPLAIN 执行计划怎么看重点？", "rows、Extra、key 各代表什么？Using filesort 和 Using temporary 多严重？"),
        ("事务隔离级别实验结果", "READ COMMITTED 下读到别人未提交数据了？是幻觉吗？"),
        ("数据库范式和反范式的取舍", "第三范式消除冗余，但查询要多 join，实际项目怎么平衡？"),
    ],
    4: [
        ("TCP 拥塞控制的四个阶段", "慢启动、拥塞避免、快重传、快恢复，窗口变化曲线谁有图？"),
        ("HTTPS 握手为什么比 HTTP 慢很多？", "非对称加密那么耗时，为什么现代网站还是秒开？"),
        ("NAT 穿透原理", "打洞成功后连接保持，中间 NAT 设备会不会超时回收？"),
    ],
    5: [
        ("进程线程协程的上下文切换成本", "进程 > 线程 > 协程，量级差多少？为什么协程便宜？"),
        ("死锁的四个必要条件记忆法", "互斥、持有等待、不可剥夺、循环等待——「李互不循」口诀谁还有更全的？"),
        ("页面置换算法实验数据", "LRU 和 Clock 在不同访问模式下差距很大，谁来分析下？"),
        ("fork 后变量为什么是独立的？", "子进程是父进程的拷贝，写时复制才分配新页——实验验证见正文。"),
    ],
}
REPLIES = [
    "同问，蹲一个老师的解答。",
    "我实验的时候也遇到过，后来发现是默认配置的问题，改配置文件就好了。",
    "看官方文档第 5 章，讲得很清楚，核心是状态机的转移。",
    "这个和上一章的知识点是联动的，建议先复习上一章。",
    "实测有效！感谢楼主，附上我的数据：性能提升约 40%。",
    "补充一点：生产环境还要考虑超时重试，不能只看理想情况。",
    "mark，下周实验课正好要交这个。",
    "老师课上讲的例子就是这个，回去翻下 PPT 第 32 页。",
]
post_created = 0
reply_created = 0
for cid, posts in DISC.items():
    roster = enroll.get(cid, students[:10])
    for title, content in posts:
        if cur.execute("SELECT 1 FROM discussion_post WHERE course_id=? AND title=?", (cid, title)).fetchone():
            continue  # 幂等：同课同题已存在
        author = random.choice(roster)
        created = days_ago(random.randint(1, 12), random.randint(8, 21), random.randint(0, 59))
        cur.execute(
            "INSERT INTO discussion_post (course_id, user_id, title, content, is_pinned, like_count, review_status, status, created_at) "
            "VALUES (?,?,?,?,0,0,1,1,?)",
            (cid, author, title, content, ts(created)))
        pid = cur.lastrowid
        post_created += 1
        # 0-4 条回复
        for _ in range(random.randint(1, 4)):
            replier = random.choice([s for s in roster if s != author] or roster)
            cur.execute(
                "INSERT INTO discussion_reply (post_id, user_id, content, like_count, review_status, created_at) "
                "VALUES (?,?,?,?,?,?)",
                (pid, replier, random.choice(REPLIES), random.randint(0, 12), 1,
                 ts(created + timedelta(hours=random.randint(1, 40)))))
            reply_created += 1
        # 点赞
        for liker in random.sample(students, k=random.randint(2, 8)):
            cur.execute("INSERT OR IGNORE INTO discussion_like (post_id, user_id, created_at) VALUES (?,?,?)",
                        (pid, liker, ts(created + timedelta(hours=random.randint(1, 72)))))
        cur.execute("UPDATE discussion_post SET like_count=? WHERE id=?",
                    (cur.execute("SELECT COUNT(*) FROM discussion_like WHERE post_id=?", (pid,)).fetchone()[0], pid))

# 教师教研区（course_id=0）真实讨论
TEACHER_ROOM = [
    (3, "关于下学期 Python 课的实验安排", "建议把 FastAPI 实验从 2 学时扩到 4 学时，学生反馈动手时间不够。"),
    (3, "期中试卷难度分析", "今年期中平均 72 分，比去年高 5 分，但简答题得分率只有 51%，明年要调整。"),
    (4, "数据结构课的图算法怎么讲更生动？", "考虑用校园导航的例子讲 Dijkstra，学生兴趣会更高。"),
    (4, "OS 课进程调度实验的分组方式", "2 人一组效果好还是独立完成好？我这边 3 人组有搭便车现象。"),
    (5, "数据库课的大作业选题", "今年做了教务系统排课，明年想换成电商秒杀场景，更有挑战性。"),
]
for tid, title, content in TEACHER_ROOM:
    if cur.execute("SELECT 1 FROM discussion_post WHERE course_id=0 AND title=?", (title,)).fetchone():
        continue
    created = days_ago(random.randint(1, 8), random.randint(9, 17), 0)
    cur.execute(
        "INSERT INTO discussion_post (course_id, user_id, title, content, is_pinned, like_count, review_status, status, created_at) "
        "VALUES (?,?,?,?,0,0,1,1,?)",
        (0, tid, title, content, ts(created)))
    pid = cur.lastrowid
    post_created += 1
    for _ in range(random.randint(1, 3)):
        rid_ = random.choice([t for t in teachers if t != tid])
        cur.execute(
            "INSERT INTO discussion_reply (post_id, user_id, content, like_count, review_status, created_at) "
            "VALUES (?,?,?,?,?,?)",
            (pid, rid_, random.choice([
                "同感，我那边也是动手时间不够，已经在申请加学时。",
                "好建议，下次教研会提一下统一调整。",
                "秒杀场景不错，涉及锁和幂等，正好覆盖知识点。",
                "分组要看考核方式，如果按组打分就会搭便车，建议个人报告+组内互评。",
            ]), random.randint(0, 6), 1, ts(created + timedelta(hours=random.randint(2, 30)))))
        reply_created += 1
print(f"[disc] 新增帖子 {post_created}，回复 {reply_created}（广场总数 "
      f"{cur.execute('SELECT COUNT(*) FROM discussion_post').fetchone()[0]}）")

# ═══════════════ 4. 私聊（三类对话流）════════════════
CHATS = [
    # (sender, receiver, 内容序列)
    (8, 3, ["李老师好，FastAPI 依赖注入实验第 3 题不太懂，能指导下吗？",
            "好的，重点看 Depends 的嵌套用法，先把 get_db 写通。",
            "明白了！还有个问题：测试的时候要 mock 数据库吗？",
            "单测用 sqlite 内存库，集成测试再上真库。",
            "收到，谢谢老师！"]),
    (9, 3, ["老师，我请假一周回家，课怎么补？", "章节视频都在课程里，进度自己安排，回来找我答疑。", "好嘞！"]),
    (8, 9, ["钱雨萱，期中你 FastAPI 考多少？", "82，扣分都在简答题。你呢？", "76，错题本刷完了，下次冲 85。", "一起加油！"]),
    (10, 11, ["孙浩然，组队做大作业不？我做后端", "好啊，我负责前端和文档", "成交，周日晚老地方讨论"]),
    (3, 4, ["王老师，下周教研会你讲图算法那节？", "对，我准备了 Dijkstra 的校园导航案例。", "期待！我也把期中分析带过去。"]),
]
msg_created = 0
for s, r_, seq in CHATS:
    base_t = days_ago(random.randint(1, 5), random.randint(9, 20), 0)
    for i, content in enumerate(seq):
        # 幂等：完全同文跳过
        if cur.execute("SELECT 1 FROM chat_message WHERE sender_id=? AND receiver_id=? AND content=?",
                       (s, r_, content)).fetchone():
            continue
        cur.execute(
            "INSERT INTO chat_message (sender_id, receiver_id, content, is_read, created_at) VALUES (?,?,?,?,?)",
            (s, r_, content, 1 if random.random() < 0.8 else 0, ts(base_t + timedelta(minutes=i * 3 + random.randint(0, 2)))))
        msg_created += 1
print(f"[chat] 新增私聊 {msg_created} 条")

# ═══════════════ 5. 签到（近 3 天）════════════════
sign_created = 0
rec_created2 = 0
for cid, c in courses.items():
    tid = c["teacher_id"]
    for d in range(3):
        day = days_ago(d, 8, random.choice([0, 5, 10, 15, 20, 25, 30, 35]))
        day_key = day.strftime("%Y-%m-%d")
        # 幂等：同课程同一天只保留一次签到任务
        if cur.execute(
            "SELECT 1 FROM sign_task WHERE course_id=? AND expire_at LIKE ?",
            (cid, f"{day_key}%"),
        ).fetchone():
            continue
        token = f"{random.randint(1000, 9999)}"
        cur.execute(
            "INSERT INTO sign_task (course_id, qrcode_token, geo_enabled, expire_at, created_by) VALUES (?,?,?,?,?)",
            (cid, token, 0, ts(day + timedelta(minutes=30)), tid))
        task_id = cur.lastrowid
        sign_created += 1
        roster = enroll.get(cid, students[:10])
        for uid in random.sample(roster, k=int(len(roster) * random.uniform(0.75, 1.0))):
            if cur.execute("SELECT 1 FROM sign_record WHERE task_id=? AND user_id=?", (task_id, uid)).fetchone():
                continue
            cur.execute(
                "INSERT INTO sign_record (task_id, user_id, sign_at, is_valid) VALUES (?,?,?,1)",
                (task_id, uid, ts(day + timedelta(seconds=random.randint(30, 1700)))))
            rec_created2 += 1
print(f"[sign] 新增签到任务 {sign_created} 个，签到记录 {rec_created2} 条")

# ═══════════════ 6. 通知（分角色 + 已读）════════════════
NOTIF = [
    ("COURSE", "《Python 后端开发》第 5 章更新", "第 5 章「数据库接入」已上线 4 个小节，含 SQLAlchemy 2.0 实战视频。", "TEACHER,STUDENT", 3, 1),
    ("EXAM", "期中考试成绩已发布", "各科期中成绩已出，请到「考试」页查看，错题本已同步。", "STUDENT", 1, 6),
    ("EVENT", "秋招宣讲会：智云科技专场", "9 月 20 日 14:00 报告厅，后端/算法岗现场收简历，扫码报名。", "STUDENT", 1, 3),
    ("SYSTEM", "平台国庆停服维护通知", "10 月 1 日 02:00-06:00 例行维护，期间无法登录。", "ALL", 1, 10),
    ("JOB", "新岗位：AI 应用开发实习生（量子智能）", "投递通道已开，要求 FastAPI + RAG 项目经验。", "STUDENT", 1, 4),
]
n_created = 0
for ntype, title, content, roles, sender, d_ago in NOTIF:
    if cur.execute("SELECT 1 FROM notification WHERE title=?", (title,)).fetchone():
        continue
    cur.execute(
        "INSERT INTO notification (type, title, content, sender_id, target_role, jump_page, push_sent, created_at) "
        "VALUES (?,?,?,?,?,?,?,?)",
        (ntype, title, content, sender, roles, "", 1, ts(days_ago(d_ago, 9, 0))))
    nid = cur.lastrowid
    n_created += 1
    # 部分已读
    for uid in random.sample(students, k=min(len(students), random.randint(5, 15))):
        cur.execute(
            "INSERT OR IGNORE INTO notification_read (notification_id, user_id, read_at) VALUES (?,?,?)",
            (nid, uid, ts(days_ago(max(0, d_ago - 1), random.randint(10, 22), 0))))
print(f"[notif] 新增通知 {n_created} 条")

# ═══════════════ 7. 学习进度补全 ═══════════════
prog_upsert = 0
# 语义：每用户每门课一行，percent 为课程总进度（0-100）
for r in cur.execute("SELECT e.user_id, e.course_id FROM course_enrollment e").fetchall():
    uid, cid = r["user_id"], r["course_id"]
    old = cur.execute("SELECT percent FROM progress WHERE user_id=? AND course_id=?", (uid, cid)).fetchone()
    if old is not None:
        # 已有进度：在其基础上自然推进（不超过 100）
        new_pct = min(100.0, round(old["percent"] + random.uniform(0, 18), 1))
        cur.execute("UPDATE progress SET percent=?, updated_at=? WHERE user_id=? AND course_id=?",
                    (new_pct, ts(days_ago(random.randint(0, 6), random.randint(8, 22), 0)), uid, cid))
    else:
        pct = round(random.uniform(15, 95), 1)
        cur.execute(
            "INSERT INTO progress (user_id, course_id, chapter_id, section_id, percent, updated_at) "
            "VALUES (?,?,NULL,NULL,?,?)",
            (uid, cid, pct, ts(days_ago(random.randint(1, 13), random.randint(8, 22), 0))))
    prog_upsert += 1
print(f"[progress] 进度覆盖 {prog_upsert} 条")

# ═══════════════ 8. 每日学习统计（近 14 天）════════════════
# 删旧重算（该表是纯聚合视图，可整体重建）
cur.execute("DELETE FROM stat_daily_learning WHERE stat_date >= ?", (ts(days_ago(14)).split()[0],))
stat_rows = 0
for d in range(13, -1, -1):
    date = days_ago(d).strftime("%Y-%m-%d")
    # USER 级
    for uid in random.sample(students, k=15):
        minutes = random.randint(15, 180)
        q_cnt = random.randint(5, 60)
        acc = round(random.uniform(0.45, 0.95), 2)
        cur.execute(
            "INSERT INTO stat_daily_learning (stat_date, scope_type, scope_id, metrics) VALUES (?,?,?,?)",
            (date, "USER", uid, json.dumps({"minutes": minutes, "questions": q_cnt, "accuracy": acc}, ensure_ascii=False)))
        stat_rows += 1
    # COURSE 级
    for cid in courses:
        minutes = random.randint(200, 900)
        q_cnt = random.randint(40, 300)
        cur.execute(
            "INSERT INTO stat_daily_learning (stat_date, scope_type, scope_id, metrics) VALUES (?,?,?,?)",
            (date, "COURSE", cid, json.dumps({"minutes": minutes, "questions": q_cnt,
                                              "active_users": random.randint(5, 18)}, ensure_ascii=False)))
        stat_rows += 1
print(f"[stats] 统计行 {stat_rows}（近 14 天）")

# ═══════════════ 9. 反馈中心（各状态真实反馈）════════════════
FEEDBACKS = [
    # (user_id, 分类, 标题, 内容, 状态, 回复)
    (8, "BUG", "考试提交后成绩没显示", "FastAPI 测验提交后一直显示待判分，刷新也不行，别的同学有显示的。", "RESOLVED", "已定位：主观题未批导致状态为 GRADING。已在考试须知中说明，成绩发布规则：主观题 24h 内批完。"),
    (9, "FEATURE", "希望错题本能导出 PDF", "错题本攒了 170 多道，期末想打印出来复习，建议加个导出 PDF 功能。", "PROCESSING", ""),
    (10, "EXPERIENCE", "讨论广场翻页有点卡", "切 100 条/页时列表加载要 2 秒多，能不能加个骨架屏。", "RESOLVED", "已优化：列表加载加了骨架屏 + 分页预取，切页 <300ms。"),
    (11, "CONTENT", "计网第 3 章有个错别字", "「拥塞避免」写成「拥塞避兔」了，在讲义第 5 页。", "RESOLVED", "感谢反馈！已修正，同步更新了讲义和课件。"),
    (12, "FEATURE", "建议自习室加白噪音", "TeacherRoom 自习室挺安静，但想有白噪音选项（雨声/翻书声），学习氛围更好。", "PENDING", ""),
    (13, "BUG", "手机号绑定收不到验证码", "改绑手机号时验证码一直收不到，换 WiFi 也不行。", "PROCESSING", "已提交运营商通道排查，预计 48h 内修复。"),
    (3, "EXPERIENCE", "组卷题库筛选希望多选", "出卷时知识点只能单选，想按多个知识点组合筛题。", "RESOLVED", "已上线：题库筛选支持多知识点 + 题型 + 难度组合。"),
    (4, "FEATURE", "希望有学业预警导出", "学情统计页很好用，建议加导出 Excel，方便报教学办。", "PENDING", ""),
    (8, "OTHER", "点赞反馈", "新版的讨论区好用多了，点个赞，希望继续保持更新节奏！", "RESOLVED", "谢谢鼓励！会持续迭代。"),
]
fb_created = 0
for uid, cat, title, content, status, reply in FEEDBACKS:
    if cur.execute("SELECT 1 FROM feedback WHERE title=?", (title,)).fetchone():
        continue
    created = days_ago(random.randint(0, 9), random.randint(9, 21), random.randint(0, 59))
    cur.execute(
        "INSERT INTO feedback (user_id, category, title, content, contact, status, reply, handled_by, handled_at, created_at, updated_at) "
        "VALUES (?,?,?,?,?,?,?,?,?,?,?)",
        (uid, cat, title, content, None, status, reply or None,
         1 if status in ("RESOLVED", "REJECTED") else None,
         ts(created + timedelta(days=1)) if status in ("RESOLVED", "REJECTED", "PROCESSING") else None,
         ts(created), ts(created + timedelta(hours=random.randint(2, 48)))))
    fb_created += 1
print(f"[feedback] 新增反馈 {fb_created} 条（四状态覆盖）")

# ═══════════════ 提交 ═══════════════
db.commit()

# ═══════════════ 汇总 ═══════════════
print("\n═══ 数据全景 ═══")
for t in ["question", "exam", "exam_paper", "exam_record", "exam_answer", "wrong_question",
          "discussion_post", "discussion_reply", "discussion_like", "chat_message",
          "sign_task", "sign_record", "notification", "progress", "stat_daily_learning",
          "friendship", "study_plan", "feedback"]:
    n = cur.execute(f"SELECT COUNT(*) FROM {t}").fetchone()[0]
    print(f"  {t}: {n}")
db.close()
print("\nDONE")
