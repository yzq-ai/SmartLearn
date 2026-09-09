"""pytest 全局夹具：为测试套件提供独立的临时数据库。

背景：测试与演示环境共用配置时会污染 smartlearn.db（注册临时用户、
改名课程、追加测试帖）。此 conftest 在导入应用配置前把 DATABASE_URL
指到独立临时库，并注入 ADMIN bootstrap，保证 pytest 全程零副作用。
"""
from __future__ import annotations

import os
import tempfile
from pathlib import Path

# 必须在导入 app.* 之前设置环境变量
_TMP_DIR = tempfile.mkdtemp(prefix="smartlearn_test_")
os.environ["DATABASE_URL"] = f"sqlite+aiosqlite:///{_TMP_DIR}/test.db"
os.environ["JWT_SECRET"] = "test-secret"
os.environ["LLM_API_KEY"] = ""  # 测试一律走规则引擎降级路径
os.environ["RATE_LIMIT_DISABLED"] = "1"  # 压测由各用例自行控制频率
