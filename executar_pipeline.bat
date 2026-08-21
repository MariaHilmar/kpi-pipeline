@echo off
chcp 65001 >nul
set "PYTHONIOENCODING=utf-8"
set "PYTHONUNBUFFERED=1"
call "%~dp0_kpi_workspace_dirs.bat"
if errorlevel 1 exit /b 1
cd /d "%PROJECT_DIR%"
set "PYTHON_EXE=python"

echo.
echo ======================================================================
echo  KPI Pipeline - GitLab para Supabase
echo ======================================================================
echo.
echo  Etapas:
echo    0 - Sync incremental de issues - GitLab API para JSON local
echo    1 - Coleta Git + processamento + sync Supabase + historico de status + snapshot diario
echo    2 - Backfill epicos (filhas do grupo no Supabase)
echo.
echo OPCOES:
echo.
echo  1 - Modo Normal - incremental
echo  2 - Modo Silent - sem saida no console
echo  3 - Modo Normal - igual opcao 1
echo  4 - Execucao Completa - reprocessa metadados + GitLab full
echo.
set /p "CHOICE=Digite 1, 2, 3 ou 4: "
if "%CHOICE%"=="" set "CHOICE=1"

if "%CHOICE%"=="4" (
    call "%~dp0executar_pipeline_completo.bat"
    exit /b %ERRORLEVEL%
)

set "MGI_REFRESH_MODE=normal"

echo.
echo Executando pipeline...
echo ======================================================================
echo.

cd /d "%PIPELINE_DIR%"
if errorlevel 1 (
    echo ERRO - Diretorio do pipeline nao encontrado: %PIPELINE_DIR%
    pause
    exit /b 1
)

echo [ETAPA 0] Sync incremental de issues - GitLab
echo ----------------------------------------------------------------------
"%PYTHON_EXE%" -u atualizar_gitlab_issues.py --incremental
if errorlevel 1 (
    echo AVISO - Nao foi possivel atualizar do GitLab. Usando JSON local.
    echo         Configure GITLAB_TOKEN no kpi-workspace\.env
)
echo.

echo [ETAPA 1] Coleta Git + sync Supabase + status_events + snapshot diario
echo ----------------------------------------------------------------------
set "MGI_STATUS_EVENTS_INCREMENTAL=1"
set "MGI_SYNC_DAILY_SNAPSHOT=1"
set "MGI_INITIAL_LOAD=0"
:: RETENCAO: 0 = mantem historico (nao poda fechadas antigas). Alinhado a pipeline.
set "MGI_CLOSED_EXCLUDE_DAYS=0"
:: HTTP GitLab: timeout baixo + paralelismo (alinhado ao .env e ao agendado).
set "MGI_GITLAB_HTTP_TIMEOUT=25"
set "MGI_GITLAB_HTTP_RETRIES=2"
set "MGI_GITLAB_HTTP_RETRY_DELAY=3"
set "MGI_GITLAB_MERGE_WORKERS=12"
set "MGI_GITLAB_EPIC_WORKERS=12"
set "MGI_GITLAB_GRAPHQL_TIMEOUT=30"
if "%CHOICE%"=="2" (
    "%PYTHON_EXE%" -u pipeline_maestro.py >nul 2>&1
) else (
    "%PYTHON_EXE%" -u pipeline_maestro.py
)

set "RESULT=%ERRORLEVEL%"

if %RESULT% equ 0 (
    echo.
    echo [ETAPA 2] Backfill epicos - filhas do grupo no Supabase
    echo ----------------------------------------------------------------------
    if "%CHOICE%"=="2" (
        "%PYTHON_EXE%" -u backfill_epicos_mergeadas.py --escopo filhas >nul 2>&1
    ) else (
        "%PYTHON_EXE%" -u backfill_epicos_mergeadas.py --escopo filhas
    )
    if errorlevel 1 (
        echo AVISO - Backfill de epicos falhou.
    )
)

echo.
echo ======================================================================
echo.

if %RESULT% equ 0 (
    echo SUCESSO - Dados sincronizados no Supabase.
    echo          Dashboard web: cd kpi-dashboard ^& npm run dev
) else (
    echo ERRO - Falha na execucao - codigo %RESULT%
)

echo.
pause
exit /b %RESULT%
