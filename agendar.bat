@echo off
REM =====================================================================
REM ATALHO PARA AGENDAR TASK SCHEDULER
REM =====================================================================
REM Executa o PowerShell com privilégios e executa o script

setlocal enabledelayedexpansion

call "%~dp0_kpi_workspace_dirs.bat"
if errorlevel 1 exit /b 1
set "PS_SCRIPT=%PIPELINE_DIR%agendar_task_scheduler.ps1"

REM Recria a tarefa com horarios: 08:10, 10:00, 12:00, 14:00, 16:00, 18:00
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "Start-Process powershell -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File ""%PS_SCRIPT%"" -Force -Times ""08:10"",""10:00"",""12:00"",""14:00"",""16:00"",""18:00""' -Verb RunAs"

endlocal
