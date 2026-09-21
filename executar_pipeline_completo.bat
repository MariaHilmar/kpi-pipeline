@echo off
chcp 65001 >nul
set "PYTHONIOENCODING=utf-8"
set "PYTHONUNBUFFERED=1"
call "%~dp0_kpi_workspace_dirs.bat"
if errorlevel 1 exit /b 1
cd /d "%PROJECT_DIR%"
set "PYTHON_EXE=python"

rem Execucao COMPLETA: GitLab full + reprocessamento de metadados no Supabase
set "KPI_REFRESH_MODE=full"
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
echo  KPI Pipeline - EXECUCAO COMPLETA
echo ======================================================================
echo.
echo  Modo: KPI_REFRESH_MODE=full
echo  - GitLab: carga completa de issues --full
echo  - Supabase: reprocessa metadados, labels, tipo e Dev/Git
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

echo [ETAPA 0] Carga completa de issues - GitLab
echo ----------------------------------------------------------------------
"%PYTHON_EXE%" -u atualizar_gitlab_issues.py --full
if errorlevel 1 (
    echo AVISO - Nao foi possivel atualizar do GitLab. Usando JSON local.
)
echo.

echo [ETAPA 1] Coleta Git + sync Supabase + status_events - execucao completa
echo ----------------------------------------------------------------------
set "KPI_STATUS_EVENTS_INCREMENTAL=1"
"%PYTHON_EXE%" -u pipeline_maestro.py --full
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
    echo SUCESSO - Execucao completa concluida!
) else (
    echo ERRO - Falha na execucao - codigo %RESULT%
)

echo.
pause
exit /b %RESULT%
