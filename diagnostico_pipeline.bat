@echo off
REM =====================================================================
REM DIAGNOSTICO - Pipeline KPI (GitLab -> Supabase)
REM =====================================================================

setlocal enabledelayedexpansion

color 0E
echo.
echo ╔════════════════════════════════════════════════════════════════════╗
echo ║           DIAGNOSTICO - KPI KPI PIPELINE (Supabase)               ║
echo ╚════════════════════════════════════════════════════════════════════╝
echo.

call "%~dp0_kpi_workspace_dirs.bat"
if errorlevel 1 exit /b 1
set "WORKSPACE_DIR=%PROJECT_DIR%"

echo [MENU]
echo.
echo  1) DIAGNOSTICO      - Verificar ambiente e dependencias
echo  2) LIMPEZA SIMPLES   - Remove logs e relatorios antigos
echo  3) LIMPEZA COMPLETA  - Reseta artefatos gerados (mantem issues JSON)
echo  4) REINSTALAR DEPS   - Reinstala dependencias Python
echo  5) TESTAR CONEXAO    - Verifica Git, WSL e Supabase (.env)
echo.

set /p CHOICE="Escolha uma opcao (1-5): "
echo.

if "%CHOICE%"=="1" goto DIAGNOSTICO
if "%CHOICE%"=="2" goto LIMPEZA_SIMPLES
if "%CHOICE%"=="3" goto LIMPEZA_COMPLETA
if "%CHOICE%"=="4" goto REINSTALAR
if "%CHOICE%"=="5" goto TESTAR_CONEXAO
goto FIM

:DIAGNOSTICO
echo [DIAGNOSTICO] Verificando ambiente...
echo.

echo [1/6] Python
where python >nul 2>&1
if errorlevel 1 (
    echo      ERRO - Python NAO encontrado no PATH
) else (
    for /f "tokens=*" %%i in ('python --version 2^>^&1') do echo      OK - %%i
)
echo.

echo [2/6] Modulos do pipeline
if exist "%PIPELINE_DIR%\pipeline_maestro.py" (echo      OK - pipeline_maestro.py) else (echo      ERRO - pipeline_maestro.py FALTANDO)
if exist "%PIPELINE_DIR%\sync_supabase.py" (echo      OK - sync_supabase.py) else (echo      ERRO - sync_supabase.py FALTANDO)
if exist "%PIPELINE_DIR%\atualizar_gitlab_issues.py" (echo      OK - atualizar_gitlab_issues.py) else (echo      ERRO - atualizar_gitlab_issues.py FALTANDO)
if exist "%PIPELINE_DIR%\coleta_git_contratos.py" (echo      OK - coleta_git_contratos.py) else (echo      ERRO - coleta_git_contratos.py FALTANDO)
if exist "%PIPELINE_DIR%\requirements.txt" (echo      OK - requirements.txt) else (echo      ERRO - requirements.txt FALTANDO)
echo.

echo [3/6] Dependencias Python
python -c "import requests; print('      OK - requests')" 2>nul || echo      ERRO - requests NAO INSTALADO
echo.

echo [4/6] Variaveis de ambiente (.env)
if exist "%WORKSPACE_DIR%.env" (
    echo      OK - .env encontrado na raiz do workspace
) else (
    echo      AVISO - .env NAO encontrado (SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, GITLAB_TOKEN)
)
echo.

echo [5/6] Artefatos de dados
if exist "%PIPELINE_DIR%\gitlab_issues_raw.json" (
    echo      OK - gitlab_issues_raw.json
) else (
    echo      AVISO - gitlab_issues_raw.json ausente (rode executar_pipeline_carga_inicial.bat)
)
if exist "%WORKSPACE_DIR%gitlab_git_data.json" (
    echo      OK - gitlab_git_data.json
) else (
    echo      AVISO - gitlab_git_data.json ausente (gerado na coleta Git)
)
echo.

echo [6/6] WSL e Git
where git >nul 2>&1
if errorlevel 1 (echo      AVISO - Git nao encontrado em Windows) else (for /f "tokens=*" %%i in ('git --version 2^>^&1') do echo      OK - %%i)
wsl --list 2>nul | findstr Ubuntu >nul
if errorlevel 1 (echo      AVISO - WSL Ubuntu nao encontrado) else (echo      OK - WSL Ubuntu disponivel)
echo.
echo [OK] Diagnostico concluido
goto FIM

:LIMPEZA_SIMPLES
echo [LIMPEZA SIMPLES] Remove logs e relatorios antigos (mantem ultimos 3)
echo.
set /p CONFIRM="Continuar? (S/N): "
if /i not "!CONFIRM!"=="S" goto CANCELADO

if exist "%WORKSPACE_DIR%Logs" (
    for /f "skip=3 tokens=*" %%f in ('dir /b /o-d "%WORKSPACE_DIR%Logs\relatorio_*.json" 2^>nul') do (
        del "%WORKSPACE_DIR%Logs\%%f" 2>nul
        echo     OK - Removido: Logs\%%f
    )
)
if exist "%WORKSPACE_DIR%logs" (
    for /f "skip=3 tokens=*" %%f in ('dir /b /o-d "%WORKSPACE_DIR%logs\*.log" 2^>nul') do (
        del "%WORKSPACE_DIR%logs\%%f" 2>nul
        echo     OK - Removido: logs\%%f
    )
)
echo.
echo [OK] Limpeza simples concluida
goto FIM

:LIMPEZA_COMPLETA
echo [LIMPEZA COMPLETA]
echo  - Remove gitlab_git_data.json
echo  - Remove gitlab_issues_sync_state.json
echo  - Remove logs e relatorios
echo  - Mantem: gitlab_issues_raw.json
echo.
echo  CUIDADO: Esta acao e IRREVERSIVEL
echo.
set /p CONFIRM="Tem certeza? Digite 'SIM' para confirmar: "
if /i not "!CONFIRM!"=="SIM" goto CANCELADO

del "%WORKSPACE_DIR%gitlab_git_data.json" 2>nul
echo     OK - gitlab_git_data.json removido

del "%PIPELINE_DIR%\gitlab_issues_sync_state.json" 2>nul
echo     OK - gitlab_issues_sync_state.json removido

if exist "%WORKSPACE_DIR%Logs" rmdir /s /q "%WORKSPACE_DIR%Logs" 2>nul
if exist "%WORKSPACE_DIR%logs" rmdir /s /q "%WORKSPACE_DIR%logs" 2>nul
echo     OK - logs removidos

echo.
echo [OK] Limpeza completa concluida
goto FIM

:REINSTALAR
echo [REINSTALACAO DE DEPENDENCIAS]
echo.
cd /d "%PIPELINE_DIR%"
if not exist "requirements.txt" (
    echo [ERRO] requirements.txt nao encontrado
    goto FIM
)
python -m pip install --upgrade -r requirements-dev.txt
if errorlevel 1 (
    echo [ERRO] Falha na instalacao
    goto FIM
)
python -c "import requests; print('[OK] requests instalado com sucesso')"
echo [OK] Dependencias reinstaladas
goto FIM

:TESTAR_CONEXAO
echo [TESTE DE CONEXAO]
echo.
echo Testando Git...
git --version
echo.
echo Testando WSL...
wsl --list -v
echo.
echo Testando repositorio contratos_v2...
wsl ls -la /root/kpi/contratos_v2 2>nul
if errorlevel 1 (
    echo AVISO - Repositorio /root/kpi/contratos_v2 inacessivel
) else (
    echo OK - Repositorio acessivel
)
echo.
echo Testando variaveis Supabase (.env)...
if not exist "%WORKSPACE_DIR%.env" (
    echo AVISO - .env ausente
) else (
    findstr /i /c:"SUPABASE_URL" "%WORKSPACE_DIR%.env" >nul && echo OK - SUPABASE_URL definido || echo AVISO - SUPABASE_URL ausente
    findstr /i /c:"SUPABASE_SERVICE_ROLE_KEY" "%WORKSPACE_DIR%.env" >nul && echo OK - SUPABASE_SERVICE_ROLE_KEY definido || echo AVISO - SUPABASE_SERVICE_ROLE_KEY ausente
    findstr /i /c:"GITLAB_TOKEN" "%WORKSPACE_DIR%.env" >nul && echo OK - GITLAB_TOKEN definido || echo AVISO - GITLAB_TOKEN ausente
)
echo.
echo [OK] Testes concluidos
goto FIM

:CANCELADO
echo [CANCELADO]

:FIM
echo.
pause
endlocal
exit /b 0
