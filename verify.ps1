#requires -Version 7.0
param(
    [Parameter(Mandatory)][ValidateSet('backend', 'android', 'ops', 'contracts', 'all')][string]$Scope,
    [string]$OpsBase
)

$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$npm = if ($IsWindows) { 'npm.cmd' } else { 'npm' }

function Invoke-Check([string]$Directory, [string]$Command, [string[]]$Arguments) {
    Push-Location (Join-Path $root $Directory)
    try {
        & $Command @Arguments
        if ($LASTEXITCODE -ne 0) { throw "$Command $($Arguments -join ' ') 失败（退出码 $LASTEXITCODE）" }
    }
    finally { Pop-Location }
}

if ($OpsBase -and $Scope -notin @('ops', 'all')) { throw '-OpsBase 仅用于 ops 或 all' }
if ($Scope -in @('backend', 'all')) {
    foreach ($command in @('build', 'vet')) { Invoke-Check 'backend' 'go' @($command, './...') }
    Invoke-Check 'backend' 'go' @('test', '-count=1', './...')
    Invoke-Check 'backend' 'go' @('build', './cmd')
    Invoke-Check 'backend' 'go' @('build', '-o', 'gizmos/gallery.exe', './gizmos/cmd/gallery')
    $references = @('-NoProfile', '-File', 'references/scripts/generate_refs.ps1')
    if (Test-Path -LiteralPath (Join-Path $root 'backend/references/generated')) {
        $references += '-Check'
    }
    Invoke-Check 'backend' 'pwsh' $references
}
if ($Scope -in @('android', 'all')) {
    Invoke-Check 'android' 'flutter' @('pub', 'get')
    Invoke-Check 'android' 'dart' @('run', 'build_runner', 'build')
    Invoke-Check 'android' 'flutter' @('analyze', '--no-pub')
    Invoke-Check 'android' 'flutter' @('test', '--no-pub')
    Invoke-Check 'android' 'flutter' @('build', 'apk', '--debug', '--no-pub')
}
if ($Scope -in @('ops', 'all')) {
    Invoke-Check 'ops/web' $npm @('ci')
    Invoke-Check 'ops/web' $npm @('run', 'build')
    Invoke-Check 'ops/web' $npm @('test')
    if ($OpsBase) {
        Invoke-Check 'backend' 'python' @('tools/smoke_ops_web.py', '--base', $OpsBase)
    }
    else { Write-Host '未提供 -OpsBase，跳过浏览器验收；完整验收请指定隔离 Monarch 实例地址。' }
}
if ($Scope -eq 'contracts') {
    Invoke-Check '.' 'pwsh' @('-NoProfile', '-File', 'backend/tools/check_contracts.ps1')
}
