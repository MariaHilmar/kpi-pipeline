@echo off
chcp 65001 >nul
setlocal EnableDelayedExpansion
call "%~dp0_kpi_workspace_dirs.bat"
if errorlevel 1 exit /b 1
cd /d "%PROJECT_DIR%"

echo.
echo ======================================================================
echo  Acompanhar pipeline agendado
echo ======================================================================
echo.
echo  Atualiza o status a cada 5 segundos. Pressione Ctrl+C para sair.
echo.

:loop
cls
echo [%date% %time%]
powershell -NoProfile -ExecutionPolicy Bypass -File "%PIPELINE_DIR%pipeline_run_status.ps1"
echo ----------------------------------------------------------------------
echo Ultimas linhas do log:
echo.

set "LOG_FILE="
for /f "delims=" %%F in ('powershell -NoProfile -Command "$s=Join-Path '%cd%' 'logs\pipeline_run_status.json'; if (Test-Path $s) { (Get-Content $s -Raw | ConvertFrom-Json).log_file }"') do set "LOG_FILE=%%F"

if defined LOG_FILE (
    if exist "!LOG_FILE!" (
        powershell -NoProfile -Command "Get-Content -Path '!LOG_FILE!' -Tail 12 -Encoding UTF8"
    ) else (
        echo Log ainda nao criado.
    )
) else (
    echo Nenhuma execucao registrada.
)

echo.
echo Proxima atualizacao em 5s... (Ctrl+C para sair)
timeout /t 5 /nobreak >nul
goto loop
