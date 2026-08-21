@echo off
REM Teste do Pipeline Maestro — GitLab -> Supabase

setlocal enabledelayedexpansion

echo ====================================================================
echo TESTE PIPELINE MAESTRO — GitLab ^> Supabase
echo ====================================================================
echo.

call "%~dp0_kpi_workspace_dirs.bat"
if errorlevel 1 exit /b 1
set "PYTHON_EXE=python"

if not exist "%PIPELINE_DIR%pipeline_maestro.py" (
    echo [ERRO] pipeline_maestro.py nao encontrado em %PIPELINE_DIR%
    exit /b 1
)

echo [INFO] Alterando para diretorio: %PIPELINE_DIR%
cd /d "%PIPELINE_DIR%"
echo.

echo [INFO] Verificando Python...
%PYTHON_EXE% --version
if errorlevel 1 (
    echo [ERRO] Python nao encontrado. Instale Python 3.11+
    exit /b 1
)
echo.

echo [INFO] Verificando dependencias...
%PYTHON_EXE% -c "import requests; print('[OK] requests encontrado')" 2>nul
if errorlevel 1 (
    echo [AVISO] requests nao encontrado. Instalando...
    %PYTHON_EXE% -m pip install -r requirements.txt
)
echo.

echo [INFO] Iniciando pipeline...
echo.
%PYTHON_EXE% pipeline_maestro.py
set RESULT=%errorlevel%
echo.

echo ====================================================================
if %RESULT% equ 0 (
    echo [SUCESSO] Pipeline concluido com exito!
) else (
    echo [ERRO] Pipeline retornou erro %RESULT%
)
echo ====================================================================
echo.

exit /b %RESULT%
