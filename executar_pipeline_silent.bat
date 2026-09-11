@echo off
REM Pipeline incremental agendado - Task Scheduler (MGI-Pipeline-Supabase)
REM
REM Etapas (alinhado ao fluxo atual do pipeline):
REM   0 - atualizar_gitlab_issues.py --incremental (GitLab -> JSON, .env + GITLAB_TOKEN)
REM   1 - pipeline_maestro.py (Git + sync Supabase + status_events + snapshot)
REM   2 - backfill_epicos_mergeadas.py --escopo filhas (epicos via Parent no Supabase)
REM
REM Saida detalhada: logs\scheduled_*.log
REM Status em tempo real: logs\pipeline_run_status.json
setlocal EnableDelayedExpansion
chcp 65001 >nul
set "PYTHONIOENCODING=utf-8"
set "PYTHONUNBUFFERED=1"

call "%~dp0_kpi_workspace_dirs.bat"
if errorlevel 1 exit /b 1
cd /d "%PROJECT_DIR%"
powershell -NoProfile -ExecutionPolicy Bypass -File "%PIPELINE_DIR%ensure_workspace_compat.ps1" -WorkspaceDir "%PROJECT_DIR%" >nul 2>&1
set "STATUS_PS1=%PIPELINE_DIR%\pipeline_run_status.ps1"
set "TEE_PS1=%PIPELINE_DIR%\run_python_tee.ps1"
set "PYTHON_EXE=python"
set "MGI_PIPELINE_SCHEDULED=1"
set "MGI_REFRESH_MODE=normal"
set "MGI_INITIAL_LOAD=0"
:: RETENCAO: 0 = NAO poda issues fechadas antigas (mantem historico do KPI
:: "Mergeadas por epoca"). Fixado aqui para nao depender do .env. O sync preserva
:: epico/mergeado_em/dev ja validados (nao sobrescreve com vazio).
set "MGI_CLOSED_EXCLUDE_DAYS=0"
set "MGI_SYNC_STATUS_EVENTS=1"
set "MGI_STATUS_EVENTS_INCREMENTAL=1"
set "MGI_SYNC_DAILY_SNAPSHOT=1"
set "MGI_LOG_RETENTION_DAYS=7"
:: HTTP GitLab: timeout BAIXO (falha rapido e re-tenta) + paralelismo evita que 1
:: request travado segure um worker. Alinhado ao .env (fonte da verdade); o .env
:: sobrescreve estes valores no load, mas os mantemos consistentes como fallback.
set "MGI_GITLAB_HTTP_TIMEOUT=25"
set "MGI_GITLAB_HTTP_RETRIES=2"
set "MGI_GITLAB_HTTP_RETRY_DELAY=3"
set "MGI_GITLAB_MERGE_WORKERS=12"
set "MGI_GITLAB_EPIC_WORKERS=12"
set "MGI_GITLAB_GRAPHQL_TIMEOUT=30"

if not exist "%PROJECT_DIR%logs" mkdir "%PROJECT_DIR%logs"

set "TS=%date:~-4%%date:~3,2%%date:~0,2%_%time:~0,2%%time:~3,2%%time:~6,2%"
set "TS=!TS: =0!"
set "LOG_FILE=%PROJECT_DIR%logs\scheduled_!TS!.log"

set "MGI_STATUS_MSG=Execucao agendada iniciada"
call :status starting init

echo.
echo ======================================================================
echo  KPI Pipeline - execucao agendada
echo ======================================================================
echo  Inicio:  %date% %time%
echo  Log:     !LOG_FILE!
echo  Status:  %PROJECT_DIR%logs\pipeline_run_status.json
echo  Dica:    a saida do Python aparece abaixo em tempo real
echo ======================================================================
echo.

call :log "============================================================"
call :log "Inicio: !date! !time!"
call :log "Diretorio: !PIPELINE_DIR!"
call :log "Modo: incremental + epicos filhas (GITLAB_TOKEN em kpi-workspace\.env)"

if not exist "%PIPELINE_DIR%\pipeline_maestro.py" (
    call :log "ERRO - pipeline_maestro.py nao encontrado"
    set "MGI_STATUS_MSG=pipeline_maestro.py nao encontrado"
    set "MGI_EXIT_CODE=1"
    call :status failed init
    call :finish 1
    exit /b 1
)

cd /d "%PIPELINE_DIR%"

set "MGI_STATUS_MSG=Limpando logs com mais de 7 dias"
call :status running log_cleanup
call :log "[PRE] Limpando logs com mais de 7 dias..."
for /f "usebackq delims=" %%L in (`%PYTHON_EXE% -u -c "from log_maintenance import executar_limpeza_logs; executar_limpeza_logs()" 2^>^&1`) do call :log "%%L"

set "MGI_STATUS_MSG=Acordando WSL Ubuntu"
call :status running wsl_wakeup
call :log "[PRE] Acordando WSL Ubuntu para coleta Git..."
wsl -d Ubuntu -e true >> "!LOG_FILE!" 2>&1
timeout /t 2 /nobreak >nul

set "MGI_STATUS_MSG=Sync incremental GitLab para JSON"
call :status running etapa_0_gitlab
call :stage_banner "ETAPA 0" "GitLab -^> JSON (issues, epicos, mergeado_em)"
call :run_python atualizar_gitlab_issues.py --incremental
if errorlevel 1 (
    call :log "AVISO - GitLab indisponivel, usando JSON local"
)
call :log "[ETAPA 0] Concluida"

set "MGI_STATUS_MSG=Coleta Git, sync Supabase, status_events e snapshot"
call :status running etapa_1_maestro
call :stage_banner "ETAPA 1" "Coleta Git + sync Supabase + status_events + snapshot"
call :run_python pipeline_maestro.py
set "RESULT=!ERRORLEVEL!"
call :log "[ETAPA 1] Concluida"

if !RESULT! equ 0 (
    set "MGI_STATUS_MSG=Backfill epicos (filhas do grupo)"
    call :status running etapa_2_epicos
    call :stage_banner "ETAPA 2" "Backfill epicos --escopo filhas"
    call :run_python backfill_epicos_mergeadas.py --escopo filhas
    if errorlevel 1 (
        call :log "AVISO - Backfill de epicos falhou; issues ja sincronizadas na etapa 1"
    ) else (
        call :log "[ETAPA 2] Concluida"
    )
) else (
    call :log "AVISO - Etapa 2 (epicos) ignorada: etapa 1 falhou"
)

call :log "Fim: !date! !time! - codigo !RESULT!"
call :log "============================================================"

if !RESULT! equ 0 (
    set "MGI_STATUS_MSG=Pipeline concluido com sucesso"
    set "MGI_EXIT_CODE=!RESULT!"
    call :status completed done
) else (
    set "MGI_STATUS_MSG=Pipeline concluido com erro"
    set "MGI_EXIT_CODE=!RESULT!"
    call :status failed done
)

call :finish !RESULT!
exit /b !RESULT!

:log
set "T=!time: =0!"
echo [!T:~0,8!] %~1
echo %~1 >> "!LOG_FILE!"
exit /b 0

:stage_banner
set "T=!time: =0!"
echo.
echo ======================================================================
echo  [%date% !T:~0,8!]  %~1  -  %~2
echo  Log: !LOG_FILE!
echo ======================================================================
echo.
exit /b 0

:run_python
set "RUN_SCRIPT=%~1"
set "RUN_ARGLINE="
if not "%~2"=="" set "RUN_ARGLINE=%~2"
if not "%~3"=="" set "RUN_ARGLINE=!RUN_ARGLINE! %~3"
if not "%~4"=="" set "RUN_ARGLINE=!RUN_ARGLINE! %~4"
if not "%~5"=="" set "RUN_ARGLINE=!RUN_ARGLINE! %~5"
REM Barra invertida no fim do path + aspas fecha o argumento cedo no PowerShell.
set "TEE_WD=!PIPELINE_DIR!"
if "!TEE_WD:~-1!"=="\" set "TEE_WD=!TEE_WD:~0,-1!"
powershell -NoProfile -ExecutionPolicy Bypass -File "!TEE_PS1!" -PythonExe "!PYTHON_EXE!" -WorkingDirectory "!TEE_WD!" -LogFile "!LOG_FILE!" -Script "!RUN_SCRIPT!" -ScriptArgLine "!RUN_ARGLINE!"
set "RUN_EXIT=!ERRORLEVEL!"
exit /b !RUN_EXIT!

:status
set "MGI_PIPELINE_STATE=%~1"
set "MGI_PIPELINE_STAGE=%~2"
set "MGI_PIPELINE_LOG=!LOG_FILE!"
if defined MGI_EXIT_CODE (
    set "MGI_EXIT_CODE=!MGI_EXIT_CODE!"
) else (
    set "MGI_EXIT_CODE="
)
powershell -NoProfile -ExecutionPolicy Bypass -File "!STATUS_PS1!" -SetFromEnv
set "MGI_EXIT_CODE="
exit /b 0

:finish
set "FINAL_CODE=%~1"
set "T=!time: =0!"
echo.
echo ======================================================================
if "%FINAL_CODE%"=="0" (
    echo  FINALIZADO COM SUCESSO
) else (
    echo  FINALIZADO COM ERRO - codigo %FINAL_CODE%
)
echo  Fim: %date% !T:~0,8!
echo  Log: !LOG_FILE!
echo.
echo  Para consultar depois: verificar_pipeline.bat
echo  Para acompanhar ao vivo: acompanhar_pipeline.bat
echo ======================================================================
echo.
if defined MGI_PIPELINE_SCHEDULED (
    exit /b %FINAL_CODE%
)
echo  Esta janela fecha em 90 segundos ou pressione uma tecla agora.
choice /c YN /t 90 /d Y /m "Fechar agora" >nul
exit /b %FINAL_CODE%
