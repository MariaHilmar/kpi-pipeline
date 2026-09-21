@echo off
REM Pull condicional da main nos repos contratos* (WSL) — agendamento ter/qui 09:00
REM Tarefa: KPI-Pull-Repos-Main
setlocal EnableDelayedExpansion
chcp 65001 >nul
set "PYTHONIOENCODING=utf-8"
set "PYTHONUNBUFFERED=1"

call "%~dp0_kpi_workspace_dirs.bat"
if errorlevel 1 exit /b 1
cd /d "%PROJECT_DIR%"
set "PYTHON_EXE=python"
set "KPI_GIT_PULL_BRANCH=auto"
set "KPI_LOG_RETENTION_DAYS=7"

if not exist "%PROJECT_DIR%logs" mkdir "%PROJECT_DIR%logs"

set "TS=%date:~-4%%date:~3,2%%date:~0,2%_%time:~0,2%%time:~3,2%%time:~6,2%"
set "TS=!TS: =0!"
set "LOG_FILE=%PROJECT_DIR%logs\pull_repos_!TS!.log"

echo.
echo ======================================================================
echo  KPI - Pull condicional main (contratos*)
echo ======================================================================
echo  Inicio:  !date! !time!
echo  Log:     !LOG_FILE!
echo ======================================================================
echo.

call :log "============================================================"
call :log "Inicio: !date! !time!"
call :log "Diretorio: !PIPELINE_DIR!"
call :log "Branch: auto (origin/HEAD por repo; fallback master)"

if not exist "%PIPELINE_DIR%\pull_repos_main.py" (
    call :log "ERRO - pull_repos_main.py nao encontrado"
    set "RESULT=1"
    call :finish !RESULT!
    exit /b 1
)

cd /d "%PIPELINE_DIR%"

call :log "[PRE] Limpando logs com mais de 7 dias..."
REM usebackq: aspas no exe + backticks no comando (evita "'python nao reconhecido")
for /f "usebackq delims=" %%L in (`"%PYTHON_EXE%" -u -c "from log_maintenance import executar_limpeza_logs; executar_limpeza_logs()" 2^>^&1`) do call :log "%%L"

call :log "[PRE] Acordando WSL Ubuntu..."
wsl -d Ubuntu -e true >> "!LOG_FILE!" 2>&1
timeout /t 2 /nobreak >nul
call :log "[PRE] WSL acordado"

call :log "[ETAPA] Pull condicional origin (em execucao...)"
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "$ErrorActionPreference='Continue';" ^
    "Set-Location -LiteralPath '%PIPELINE_DIR%';" ^
    "$env:PYTHONIOENCODING='utf-8';" ^
    "$env:PYTHONUNBUFFERED='1';" ^
    "$env:KPI_GIT_PULL_BRANCH='auto';" ^
    "$out = & '%PYTHON_EXE%' -u pull_repos_main.py 2>&1;" ^
    "$code = $LASTEXITCODE;" ^
    "$out | ForEach-Object { $_; Add-Content -LiteralPath '%LOG_FILE%' -Value $_ -Encoding utf8 };" ^
    "exit $code"
set "RESULT=!ERRORLEVEL!"
call :log "[ETAPA] Concluida"

call :log "Fim: !date! !time! - codigo !RESULT!"
call :log "============================================================"

call :finish !RESULT!
exit /b !RESULT!

:log
echo %~1
echo %~1 >> "!LOG_FILE!"
exit /b 0

:finish
set "FINAL_CODE=%~1"
echo.
echo ======================================================================
if "%FINAL_CODE%"=="0" (
    echo  FINALIZADO COM SUCESSO
) else (
    echo  FINALIZADO COM ERRO - codigo %FINAL_CODE%
)
echo ======================================================================
echo  Fim: !date! !time!
echo  Log: !LOG_FILE!
echo.
echo  Esta janela fecha em 90 segundos ou pressione uma tecla agora.
echo ======================================================================
echo.
choice /c YN /t 90 /d Y /m "Fechar agora" >nul
exit /b %FINAL_CODE%
