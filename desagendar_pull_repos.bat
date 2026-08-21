@echo off
REM Remove agendamento MGI-Pull-Repos-Main (requer admin)
setlocal
call "%~dp0_kpi_workspace_dirs.bat"
if errorlevel 1 exit /b 1
set "PS_SCRIPT=%PIPELINE_DIR%desagendar_pull_repos.ps1"
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "Start-Process powershell -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File \"\"%PS_SCRIPT%\"\"' -Verb RunAs"
endlocal
