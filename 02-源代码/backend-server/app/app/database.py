"""Database engine, session factory and idempotent schema bootstrap.

This is the single canonical module for ``Base``, the async engine, the session
factory, ``get_db`` and ``init_db``. ``app.db.session`` re-exports these names
for backward compatibility.
"""
from __future__ import annotations

from collections.abc import AsyncGenerator

from sqlalchemy.engine import make_url
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine
from sqlalchemy.orm import DeclarativeBase

from app.core.config import settings


def _normalize_database_url(raw_url: str) -> str:
    """Accept common deployment URLs while forcing async drivers."""
    url = make_url(raw_url)
    if url.drivername == "sqlite":
        url = url.set(drivername="sqlite+aiosqlite")
    elif url.drivername in {"mysql", "mysql+pymysql", "mysql+mysqldb"}:
        url = url.set(drivername="mysql+aiomysql")
    return url.render_as_string(hide_password=False)


DATABASE_URL = _normalize_database_url(settings.database_url)
engine = create_async_engine(DATABASE_URL, future=True)
SessionLocal = async_sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)


class Base(DeclarativeBase):
    pass


async def get_db() -> AsyncGenerator[AsyncSession, None]:
    async with SessionLocal() as session:
        yield session


async def _migrate_lightweight(conn) -> None:
    """对已有库补充后期新增的列（create_all 不会 ALTER 旧表）。幂等。"""
    from sqlalchemy import text

    columns = {
        "sys_user": {"signature": "VARCHAR(200) NULL DEFAULT ''", "user_code": "VARCHAR(12) NULL DEFAULT ''"},
        "course": {
            "start_date": "VARCHAR(20) NULL", "end_date": "VARCHAR(20) NULL",
            "class_time": "VARCHAR(100) NULL", "location": "VARCHAR(100) NULL", "exam_time": "VARCHAR(100) NULL",
        },
    }
    dialect = conn.dialect.name  # sqlite / mysql
    for table, cols in columns.items():
        for col, ddl in cols.items():
            try:
                await conn.execute(text(f"ALTER TABLE {table} ADD COLUMN {col} {ddl}"))
            except Exception:  # noqa: BLE001 - 列已存在等场景直接跳过
                pass
    # 教研区哨兵课程行（course_id=0 被 discussion_post 外键引用；MySQL 强制外键，必须存在此行）
    try:
        from datetime import datetime as _dt

        if dialect == "mysql":
            # MySQL 默认把 AUTO_INCREMENT 主键的 0 当作"生成新值"，须显式允许写 0
            await conn.execute(text("SET SESSION sql_mode = CONCAT(@@sql_mode, ',NO_AUTO_VALUE_ON_ZERO')"))
        _now = _dt.utcnow().strftime("%Y-%m-%d %H:%M:%S")
        await conn.execute(text(
            "INSERT INTO course (id, course_code, title, description, teacher, status, student_count, created_at, updated_at) "
            "VALUES (0, 'STAFF-ROOM', '教研专区', '教师教研讨论专用空间（不对学生开放）', '教研组', 0, 0, :ca, :ua)"
        ), {"ca": _now, "ua": _now})
    except Exception:  # noqa: BLE001 - 已存在（唯一键冲突）直接跳过
        pass
    # user_code 唯一索引（两方言幂等写法分别处理）
    from sqlalchemy import inspect as sa_inspect
    try:
        def _has_index(sync_conn) -> bool:
            insp = sa_inspect(sync_conn)
            return any(
                ix.get("unique") and ix.get("column_names") == ["user_code"]
                for ix in insp.get_indexes("sys_user")
            )
        exists = await conn.run_sync(_has_index)
        if not exists:
            if dialect == "mysql":
                await conn.execute(text("CREATE UNIQUE INDEX uq_sys_user_code ON sys_user (user_code)"))
            else:
                await conn.execute(text("CREATE UNIQUE INDEX IF NOT EXISTS uq_sys_user_code ON sys_user (user_code)"))
    except Exception:  # noqa: BLE001
        pass


async def init_db() -> None:
    """建表（幂等）+ 轻量迁移 + 写入种子数据（幂等）。"""
    import app.models  # noqa: F401  # 注册所有模型到 metadata

    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
        await _migrate_lightweight(conn)

    from app.seed import seed_data

    async with SessionLocal() as db:
        await seed_data(db)
