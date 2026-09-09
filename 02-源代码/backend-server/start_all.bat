@echo off
REM SmartLearn 一键启动（MySQL + FastAPI）
REM 用法：start_all.bat [mysql密码] [库名] [--skip-migrate]
setlocal
cd /d %~dp0

set MYSQL_PASSWORD=%1
if "%MYSQL_PASSWORD%"=="" set MYSQL_PASSWORD=123456
set DB_NAME=%2
if "%DB_NAME%"=="" set DB_NAME=smartlearn
set EXTRA_ARGS=%3 %4 %5

echo ================================================
echo   SmartLearn 一键启动（MySQL + FastAPI）
echo   MySQL: root@127.0.0.1:3306 / %DB_NAME%
echo   密码: %MYSQL_PASSWORD%
echo ================================================
echo.

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0start_all.ps1" -MysqlPassword %MYSQL_PASSWORD% -DbName %DB_NAME% %EXTRA_ARGS%

endlocal