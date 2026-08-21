# Garante junction D:\mgi-workspace -> workspace atual (compatibilidade com Task Scheduler antigo).
param(
    [string]$WorkspaceDir = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'
$legacyPath = 'D:\mgi-workspace'
$workspace = (Resolve-Path -LiteralPath $WorkspaceDir).Path

if ($workspace -ieq $legacyPath) {
    exit 0
}

if (Test-Path -LiteralPath $legacyPath) {
    $item = Get-Item -LiteralPath $legacyPath -Force
    if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
        $target = ($item | Get-Item).Target
        if ($target -contains $workspace -or $target -eq $workspace) {
            exit 0
        }
        Write-Warning "Junction $legacyPath aponta para $target (esperado: $workspace)"
        exit 1
    }
    Write-Warning "$legacyPath existe como pasta real; nao foi alterado"
    exit 1
}

$parent = Split-Path -Parent $legacyPath
if (-not (Test-Path -LiteralPath $parent)) {
    Write-Warning "Disco/pasta pai de $legacyPath nao existe"
    exit 1
}

$result = cmd /c "mklink /J `"$legacyPath`" `"$workspace`"" 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Warning "Falha ao criar junction ${legacyPath} -> ${workspace}: $result"
    exit $LASTEXITCODE
}

Write-Host "OK - Junction criada: $legacyPath -> $workspace"
exit 0
