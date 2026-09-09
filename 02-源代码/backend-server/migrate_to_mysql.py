# -*- coding: utf-8 -*-
"""
一键迁移：SQLite -> MySQL（全量数据搬移，保留自增 ID 与外键关系）。

用法：
  python migrate_to_mysql.py                 # 迁移到默认库 smartlearn
  python migrate_to_mysql.py --db smartlearn --host 127.0.0.1 --user root --password 123456

前置：
  pip install pymysql
  MySQL 8.x 服务运行中，账号有建库建表权限。
"""
from __future__ import annotations

import argparse
import io
import sys

import pymysql

if hasattr(sys.stdout, "buffer"):
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")

# ── 按外键依赖排序的表清单（父表在前）──
TABLE_ORDER = [
    "sys_user",
    "sys_config",
    "sensitive_word",
    "course",
    "company",
    "student_profile",
    "resume",
    "chapter",
    "course_enrollment",
    "course_skill_tag",
    "job_skill_tag",
    "knowledge_point",
    "exam_paper",
    "question",
    "exam",
    "exam_record",
    "exam_answer",
    "assignment",
    "job_posting",
    "career_event",
    "notification",
    "sign_task",
    "discussion_post",
    "section",
    "resource",
    "student_kp_mastery",
    "job_application",
    "job_favorite",
    "career_event_signup",
    "notification_read",
    "sign_record",
    "discussion_reply",
    "discussion_like",
    "exam_paper_question",
    "assignment_submission",
    "progress",
    "wrong_question",
    "friendship",
    "chat_message",
    "discussion_reply_like",
    "study_plan",
    "ai_chat_log",
    "stat_daily_learning",
    "sys_login_log",
    "sys_audit_log",
    "feedback",
    "job_favorite",  # 重复无害
]

EXCLUDE_TABLES = {"sqlite_sequence"}


def main() -> int:
    parser = argparse.ArgumentParser(description="SQLite -> MySQL 全量迁移")
    parser.add_argument("--sqlite", default="smartlearn.db")
    parser.add_argument("--db", default="smartlearn")
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=3306)
    parser.add_argument("--user", default="root")
    parser.add_argument("--password", default="123456")
    parser.add_argument("--drop-existing", action="store_true", help="目标库已存在时先 DROP（危险）")
    args = parser.parse_args()

    import sqlite3

    lite = sqlite3.connect(args.sqlite)
    lite.row_factory = sqlite3.Row

    existing = {r[0] for r in lite.execute("SELECT name FROM sqlite_master WHERE type='table'")} - EXCLUDE_TABLES
    print(f"[sqlite] 发现 {len(existing)} 张表")

    # ── 连接 MySQL（不带库名）──
    try:
        admin_conn = pymysql.connect(
            host=args.host, port=args.port, user=args.user, password=args.password,
            charset="utf8mb4", autocommit=True,
        )
    except Exception as e:  # noqa: BLE001
        print(f"[mysql] 连接失败: {e}")
        return 1
    admin_cur = admin_conn.cursor()

    # ── 建库（utf8mb4 支持完整中文/emoji）──
    admin_cur.execute(
        f"CREATE DATABASE IF NOT EXISTS `{args.db}` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci"
    )
    print(f"[mysql] 库 `{args.db}` 就绪（utf8mb4）")

    if args.drop_existing:
        admin_cur.execute(f"DROP DATABASE IF EXISTS `{args.db}`")
        admin_cur.execute(
            f"CREATE DATABASE `{args.db}` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci"
        )
        print(f"[mysql] 已重建库 `{args.db}`")

    conn = pymysql.connect(
        host=args.host, port=args.port, user=args.user, password=args.password,
        database=args.db, charset="utf8mb4", autocommit=False,
    )
    cur = conn.cursor()
    FK_CHECK = "SET FOREIGN_KEY_CHECKS=0"
    cur.execute(FK_CHECK)

    total_rows = 0
    migrated = 0
    # 先让 SQLAlchemy 建表（幂等 create_all），再灌数据
    import asyncio
    os_env_url = (
        f"mysql+aiomysql://{args.user}:{args.password}@{args.host}:{args.port}/{args.db}"
    )
    import os
    os.environ["DATABASE_URL"] = os_env_url

    async def create_schema() -> None:
        # 重新加载 settings（清缓存）后调用 init_db 建表
        import importlib
        import app.core.config as cfg
        importlib.reload(cfg)
        import app.database as dbm
        importlib.reload(dbm)
        await dbm.init_db()

    asyncio.run(create_schema())
    print("[schema] MySQL 建表完成（create_all 幂等）")

    for table in TABLE_ORDER:
        if table not in existing:
            continue
        rows = lite.execute(f"SELECT * FROM {table}").fetchall()
        if not rows:
            print(f"  {table:28s} (空表，跳过)")
            continue
        cols = rows[0].keys()
        n = len(rows)
        total_rows += n
        migrated += 1
        placeholders = ", ".join(["%s"] * len(cols))
        col_sql = ", ".join(f"`{c}`" for c in cols)
        try:
            cur.execute(f"DELETE FROM `{table}`")
            cur.executemany(
                f"INSERT INTO `{table}` ({col_sql}) VALUES ({placeholders})",
                [tuple(r) for r in rows],
            )
            print(f"  {table:28s} {n} rows OK")
        except pymysql.err.ProgrammingError as e:
            if "doesn't exist" in str(e):
                conn.rollback()
                print(f"\n[错误] 表 {table} 建表失败: {e}")
                return 2
            raise
        # 自增游标恢复（仅含 id 列的表）
        has_id = "id" in cols
        if has_id:
            max_id = lite.execute(f"SELECT MAX(id) FROM {table}").fetchone()[0] or 0
            if max_id:
                cur.execute(f"ALTER TABLE `{table}` AUTO_INCREMENT = {max_id + 1}")

    conn.commit()
    cur.execute("SET FOREIGN_KEY_CHECKS=1")
    conn.commit()
    print(f"\n[migrate] {migrated} tables {total_rows} rows -> mysql://{args.host}:{args.port}/{args.db}")
    lite.close()
    conn.close()
    admin_conn.close()
    return 0


if __name__ == "__main__":
    sys.exit(main())
