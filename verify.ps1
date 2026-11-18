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
    Invoke-Check 'backend' 'go' @('vet', './...')
    Invoke-Check 'backend' 'go' @('test', './...')
}
if ($Scope -in @('android', 'all')) {
    Invoke-Check 'android' 'flutter' @('analyze', '--no-pub')
    Invoke-Check 'android' 'flutter' @('test', '--no-pub')
}
if ($Scope -in @('ops', 'all')) {
    Invoke-Check 'ops/web' $npm @('test')
    Invoke-Check 'ops/web' $npm @('run', 'check:build')
    if ($OpsBase) {
        Invoke-Check 'backend' 'python' @('tools/smoke_ops_web.py', '--base', $OpsBase)
    }
}
if ($Scope -eq 'contracts') {
    & (Join-Path $root 'backend/tools/check_contracts.ps1')
}
