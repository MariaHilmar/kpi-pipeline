# Atualiza logs/pipeline_run_status.json (acompanhar_pipeline.bat e execucao agendada).
param(
    [switch]$SetFromEnv
)

$workspace = Split-Path -Parent $PSScriptRoot
$statusPath = Join-Path $workspace 'logs\pipeline_run_status.json'
$logsDir = Split-Path -Parent $statusPath
if (-not (Test-Path $logsDir)) {
    New-Item -ItemType Directory -Path $logsDir -Force | Out-Null
}

if ($SetFromEnv) {
    $now = Get-Date -Format 'o'
    $payload = [ordered]@{
        state      = $env:MGI_PIPELINE_STATE
        stage      = $env:MGI_PIPELINE_STAGE
        message    = $env:MGI_STATUS_MSG
        pid        = $PID
        log_file   = $env:MGI_PIPELINE_LOG
        updated_at = $now
    }
    if ($env:MGI_EXIT_CODE) {
        $payload.exit_code = [int]$env:MGI_EXIT_CODE
    }
    if ($env:MGI_PIPELINE_STATE -in @('completed', 'failed')) {
        $payload.finished_at = $now
    }
    $payload | ConvertTo-Json | Set-Content -LiteralPath $statusPath -Encoding utf8
    exit 0
}

if (-not (Test-Path $statusPath)) {
    Write-Host 'Nenhuma execucao registrada.'
} else {
    $data = Get-Content -LiteralPath $statusPath -Raw -Encoding utf8 | ConvertFrom-Json
    Write-Host "Estado:  $($data.state)"
    Write-Host "Etapa:   $($data.stage)"
    Write-Host "Mensagem: $($data.message)"
    if ($data.log_file) { Write-Host "Log:     $($data.log_file)" }
    if ($data.updated_at) { Write-Host "Atualizado: $($data.updated_at)" }
    if ($null -ne $data.exit_code) { Write-Host "Codigo:  $($data.exit_code)" }
}

Write-Host ''
Write-Host '--- Agendamento (Task Scheduler) ---'
$taskNames = @('MGI-Pipeline-Supabase', 'MGI-Pull-Repos-Main')
$expectedBatch = Join-Path $PSScriptRoot 'executar_pipeline_silent.bat'
foreach ($taskName in $taskNames) {
    $task = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
    if (-not $task) {
        Write-Host "[$taskName] NAO encontrada - rode agendar.bat (admin)"
        continue
    }
    $action = $task.Actions | Select-Object -First 1
    $taskPath = if ($action.Arguments -match '"([^"]+\.bat)"') { $Matches[1] } else { $action.Arguments }
    $taskDir = $action.WorkingDirectory
    $info = Get-ScheduledTaskInfo -TaskName $taskName -ErrorAction SilentlyContinue
    $lastResult = if ($info) { $info.LastTaskResult } else { $null }
    $nextRun = if ($info) { $info.NextRunTime } else { $null }

  if ($taskPath -and -not (Test-Path -LiteralPath $taskPath)) {
        $legacyJunction = 'D:\mgi-workspace'
        if ((Test-Path -LiteralPath $legacyJunction) -and ($taskPath -like "$legacyJunction*")) {
            Write-Host "[$taskName] AVISO - tarefa usa caminho antigo, mas junction existe: $legacyJunction" -ForegroundColor Yellow
            Write-Host "             Rode agendar.bat (admin) para atualizar para: $expectedBatch" -ForegroundColor Yellow
        } else {
            Write-Host "[$taskName] ERRO - caminho invalido: $taskPath" -ForegroundColor Red
            Write-Host "             Esperado neste workspace: $expectedBatch" -ForegroundColor Yellow
            Write-Host '             Correcao: duplo-clique em agendar.bat (como admin)' -ForegroundColor Yellow
        }
    } elseif ($taskDir -and -not (Test-Path -LiteralPath $taskDir)) {
        Write-Host "[$taskName] ERRO - diretorio invalido: $taskDir" -ForegroundColor Red
        Write-Host '             Correcao: duplo-clique em agendar.bat (como admin)' -ForegroundColor Yellow
    } else {
        Write-Host "[$taskName] OK - $taskPath"
    }
    if ($lastResult -eq 2147942667) {
        Write-Host '             Ultimo resultado: 0x8007010B (diretorio invalido)' -ForegroundColor Red
    } elseif ($null -ne $lastResult -and $lastResult -ne 0) {
        Write-Host "             Ultimo resultado: $lastResult"
    }
    if ($nextRun) { Write-Host "             Proxima execucao: $nextRun" }
}
