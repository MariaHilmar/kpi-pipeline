@echo off
chcp 65001 >nul
call "%~dp0_kpi_workspace_dirs.bat"
if errorlevel 1 exit /b 1
cd /d "%PROJECT_DIR%"
powershell -NoProfile -ExecutionPolicy Bypass -File "%PIPELINE_DIR%pipeline_run_status.ps1"
echo.
pause
