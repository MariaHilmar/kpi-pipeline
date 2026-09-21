@echo off
chcp 65001 >nul
set "PYTHONIOENCODING=utf-8"
set "PYTHONUNBUFFERED=1"
call "%~dp0_kpi_workspace_dirs.bat"
if errorlevel 1 exit /b 1
cd /d "%PROJECT_DIR%"
set "PYTHON_EXE=python"

rem CARGA INICIAL: todos os modulos + historico - sem filtro 60 dias fechadas
set "KPI_ALL_MODULES=1"
set "KPI_INITIAL_LOAD=1"
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
echo  KPI Pipeline - CARGA INICIAL - TODOS MODULOS
echo ======================================================================
echo.
echo  Modo: KPI_ALL_MODULES=1, KPI_INITIAL_LOAD=1
echo  Filtro 60 dias fechadas: DESATIVADO
echo  Data de corte: 01/01/2024 - config.py
echo.
echo  Apos esta carga, use executar_pipeline.bat para sync incremental.
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

echo [ETAPA 1] Coleta Git + sync Supabase + status_events - carga inicial
echo ----------------------------------------------------------------------
set "KPI_STATUS_EVENTS_INCREMENTAL=1"
"%PYTHON_EXE%" -u pipeline_maestro.py --all-modules --initial-load
set "RESULT=%ERRORLEVEL%"

echo.
echo ======================================================================
echo.

if %RESULT% equ 0 (
    echo SUCESSO - Carga inicial concluida!
    echo.
    echo Proximas atualizacoes: use executar_pipeline.bat - incremental.
) else (
    echo ERRO - Falha na execucao - codigo %RESULT%
)

echo.
pause
exit /b %RESULT%
