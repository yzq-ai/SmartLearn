# SmartLearn 一键启动（PowerShell）
# ─────────────────────────────────────────────
# 功能：MySQL 检查/启动 → 建库 → ORM 建表+基础种子 → SQLite 全量数据迁移（可选）→ FastAPI 后端启动
# 用法：
#   .\start_all.ps1                        # 默认 root/123456@127.0.0.1:3306/smartlearn
#   .\start_all.ps1 -MysqlPassword xxx     # 自定义密码
#   .\start_all.ps1 -SkipMigrate           # MySQL 已有数据，跳过迁移
#   .\start_all.ps1 -SkipSeed              # 跳过真实数据补全
# 双击 start_all.bat 即可运行本脚本。
param(
    [string]$MysqlHost = "127.0.0.1",
    [int]$MysqlPort = 3306,
    [string]$MysqlUser = "root",
    [string]$MysqlPassword = "123456",
    [string]$DbName = "smartlearn",
    [int]$BackendPort = 8000,
    [switch]$SkipMigrate,
    [switch]$SkipSeed
)
$ErrorActionPreference = "Stop"
$root = $PSScriptRoot
Set-Location $root

$py = Join-Path $root ".venv\Scripts\python.exe"
if (-not (Test-Path $py)) { $py = "python" }

function Step($msg) { Write-Host "`n==> $msg" -ForegroundColor Cyan }
function Fail($msg) { Write-Host "[错误] $msg" -ForegroundColor Red; exit 1 }

Step "环境检查（$py）"
& $py --version
if ($LASTEXITCODE -ne 0) { Fail "Python 不可用" }

# ─────────────────────────────────────────────
# 1. MySQL 服务
# ─────────────────────────────────────────────
Step "MySQL 服务检查（$MysqlHost`:$MysqlPort）"
$svc = Get-Service mysql -ErrorAction SilentlyContinue
if ($svc) {
    Write-Host "Windows 服务 mysql: $($svc.Status)"
    if ($svc.Status -ne "Running") {
        Write-Host "启动 MySQL 服务…"
        Start-Service mysql
        if ($?) { Write-Host "MySQL 服务已启动" } else { Fail "MySQL 服务启动失败" }
    }
} else {
    Write-Host "未找到 Windows 服务 'mysql'（可能是 docker/远程实例），继续直连…"
}

Step "连接 MySQL 并建库 $DbName"
$env:PYTHONIOENCODING = "utf-8"
& $py -c @"
import pymysql
c = pymysql.connect(host='$MysqlHost', port=$MysqlPort, user='$MysqlUser', password='$MysqlPassword')
print('MySQL', c.get_server_info())
cur = c.cursor()
cur.execute('CREATE DATABASE IF NOT EXISTS ``$DbName`` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci')
print('数据库 $DbName 就绪')
c.close()
"@
if ($LASTEXITCODE -ne 0) { Fail "MySQL 连接/建库失败（检查服务与账号密码）" }

# ─────────────────────────────────────────────
# 2. DATABASE_URL 持久化到 .env
# ─────────────────────────────────────────────
Step "写入 .env（MySQL 连接串）"
$dbUrl = "mysql+aiomysql://${MysqlUser}:${MysqlPassword}@${MysqlHost}:${MysqlPort}/${DbName}?charset=utf8mb4"
"$dbUrl" | Out-Null
# UTF-8 无 BOM 写入（BOM 会污染 DATABASE_URL 导致 seed 脚本静默回退 SQLite）
[System.IO.File]::WriteAllText((Join-Path $root ".env"), "DATABASE_URL=$dbUrl`nJWT_SECRET=smartlearn-jwt-2026-change-in-prod`n", (New-Object System.Text.UTF8Encoding($false)))
Write-Host "DATABASE_URL = $dbUrl"

# ─────────────────────────────────────────────
# 3. 建表 + 基础种子（幂等）
# ─────────────────────────────────────────────
Step "ORM 建表 + 基础种子数据（幂等 create_all + seed_data）"
$env:DATABASE_URL = $dbUrl
& $py -c @"
import asyncio, os
os.environ['DATABASE_URL'] = '$dbUrl'
from app.database import init_db
asyncio.run(init_db())
print('建表与基础种子完成')
"@
if ($LASTEXITCODE -ne 0) { Fail "建表/种子失败" }

# ─────────────────────────────────────────────
# 4. SQLite → MySQL 全量迁移（可选）
# ─────────────────────────────────────────────
if (-not $SkipMigrate) {
    $sqliteDb = Join-Path $root "smartlearn.db"
    if (Test-Path $sqliteDb) {
        Step "迁移 SQLite 全量数据 → MySQL（保留 ID 与外键关系）"
        & $py (Join-Path $root "migrate_to_mysql.py") --sqlite $sqliteDb --db $DbName --host $MysqlHost --port $MysqlPort --user $MysqlUser --password $MysqlPassword
        if ($LASTEXITCODE -ne 0) {
            Write-Host "[警告] 迁移返回码 $LASTEXITCODE —— MySQL 已有数据时属正常，可加 -SkipMigrate 跳过" -ForegroundColor Yellow
        }
    } else {
        Write-Host "未发现 smartlearn.db（空库部署），跳过迁移"
    }
}

# ─────────────────────────────────────────────
# 5. 真实数据补全（可选，幂等）
# ─────────────────────────────────────────────
if (-not $SkipSeed) {
    Step "生成/补全真实数据（seed_real_data.py，幂等）"
    & $py (Join-Path $root "seed_real_data.py")
    if ($LASTEXITCODE -ne 0) { Write-Host "[警告] 真实数据脚本未完全成功（多为已存在跳过）" -ForegroundColor Yellow }
}

# ─────────────────────────────────────────────
# 6. 启动后端
# ─────────────────────────────────────────────
Step "启动 FastAPI 后端（0.0.0.0:$BackendPort）"
Write-Host "API 文档: http://127.0.0.1:$BackendPort/docs    Ctrl+C 停止" -ForegroundColor Green
& $py -m uvicorn app.main:app --host 0.0.0.0 --port $BackendPort
