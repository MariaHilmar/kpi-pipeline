@echo off
chcp 65001 >nul
set "PYTHONIOENCODING=utf-8"
set "PYTHONUNBUFFERED=1"
call "%~dp0_kpi_workspace_dirs.bat"
if errorlevel 1 exit /b 1
cd /d "%PROJECT_DIR%"
set "PYTHON_EXE=python"

rem Todos os modulos, sync incremental - mantem historico (retencao total)
set "KPI_ALL_MODULES=1"
:: RETENCAO: 0 = mantem historico (nao poda fechadas antigas). Alinhado a pipeline.
set "KPI_CLOSED_EXCLUDE_DAYS=0"
:: HTTP GitLab: timeout baixo + paralelismo (alinhado ao .env e ao agendado).
set "KPI_GITLAB_HTTP_TIMEOUT=25"
set "KPI_GITLAB_HTTP_RETRIES=2"
set "KPI_GITLAB_HTTP_RETRY_DELAY=3"
set "KPI_GITLAB_MERGE_WORKERS=12"
set "KPI_GITLAB_EPIC_WORKERS=12"
set "KPI_GITLAB_GRAPHQL_TIMEOUT=30"

echo.
echo ======================================================================
echo  KPI Pipeline - TODOS MODULOS [INCREMENTAL]
echo ======================================================================
echo.
echo  Modo: KPI_ALL_MODULES=1
echo  Filtro: issues fechadas ha mais de 60 dias sao EXCLUIDAS
echo.
echo  Para a primeira carga, use executar_pipeline_carga_inicial.bat
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
)
echo.

echo [ETAPA 1] Coleta Git + sync Supabase + status_events - todos os modulos
echo          Aguarde - pode levar alguns minutos...
echo ----------------------------------------------------------------------
set "KPI_STATUS_EVENTS_INCREMENTAL=1"
"%PYTHON_EXE%" -u pipeline_maestro.py --all-modules
set "RESULT=%ERRORLEVEL%"

if %RESULT% equ 0 (
    echo.
    echo [ETAPA 2] Backfill epicos - filhas do grupo no Supabase
    echo ----------------------------------------------------------------------
    "%PYTHON_EXE%" -u backfill_epicos_mergeadas.py --escopo filhas
)

echo.
echo ======================================================================
echo.

if %RESULT% equ 0 (
    echo SUCESSO - Sync concluido com todos os modulos!
) else (
    echo ERRO - Falha na execucao - codigo %RESULT%
)

echo.
pause
exit /b %RESULT%
