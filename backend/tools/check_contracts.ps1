#requires -Version 7.0
param([ValidateSet('all', 'backend', 'android', 'ops')][string]$Scope = 'all')

$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path

if ($Scope -in @('all', 'backend')) {
    Push-Location (Join-Path $root 'backend')
    try {
        go test ./internal/repository ./internal/service/ai -run '^Test(UserDataContract|OnlineSyncRejectsStaleSnapshotAtomically|ProgressDoesNotProbe)$'
        if ($LASTEXITCODE -ne 0) { throw 'Go 契约检查失败' }
    }
    finally { Pop-Location }
}

if ($Scope -in @('all', 'android')) {
    Push-Location (Join-Path $root 'android')
    try {
        flutter test --no-pub test/user_data_contract_test.dart
        if ($LASTEXITCODE -ne 0) { throw 'Android 契约检查失败' }
    }
    finally { Pop-Location }
}

if ($Scope -in @('all', 'ops')) {
    Push-Location $root
    try {
        node --test ops/tests/contracts.mjs
        if ($LASTEXITCODE -ne 0) { throw 'Ops 契约检查失败' }
    }
    finally { Pop-Location }
}
