@echo off
REM Define PROJECT_DIR (raiz do workspace) e PIPELINE_DIR.
REM Funciona se este .bat estiver na raiz do workspace OU dentro de kpi-pipeline.
set "KPI_HERE=%~dp0"
if exist "%KPI_HERE%pipeline_maestro.py" (
  set "PIPELINE_DIR=%KPI_HERE%"
  pushd "%KPI_HERE%.."
  set "PROJECT_DIR=%CD%\"
  popd
  goto :eof
)
if exist "%KPI_HERE%kpi-pipeline\pipeline_maestro.py" (
  set "PROJECT_DIR=%KPI_HERE%"
  set "PIPELINE_DIR=%KPI_HERE%kpi-pipeline\"
  goto :eof
)
echo ERRO - Nao encontrei pipeline_maestro.py.
echo Coloque os atalhos .bat na raiz do workspace ou na pasta kpi-pipeline.
exit /b 1
