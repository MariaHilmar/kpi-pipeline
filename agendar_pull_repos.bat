@echo off
REM Agenda pull condicional main (mensal, dia 01 09:00) — requer admin
setlocal
call "%~dp0_kpi_workspace_dirs.bat"
if errorlevel 1 exit /b 1
set "PS_SCRIPT=%PIPELINE_DIR%agendar_pull_repos.ps1"
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "Start-Process powershell -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File \"\"%PS_SCRIPT%\"\" -Force' -Verb RunAs"
endlocal
