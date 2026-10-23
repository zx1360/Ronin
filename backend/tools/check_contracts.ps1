$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path

Push-Location (Join-Path $root 'backend')
try {
    go test ./cmd ./internal/repository ./internal/service/ai ./internal/service/server ./internal/service/taskengine -run 'Test(UserDataContract|ProgressDoesNotProbe|EnsureReadyChecksCachedModelServer|ServeShutdown|CloseWaitsAndRejectsNewTasks|StartupFailureClosesDatabase)$'
    if ($LASTEXITCODE -ne 0) { throw 'Go 契约或生命周期检查失败' }
}
finally { Pop-Location }

Push-Location (Join-Path $root 'android')
try {
    flutter test test/user_data_contract_test.dart
    if ($LASTEXITCODE -ne 0) { throw 'Android 契约检查失败' }
}
finally { Pop-Location }

Push-Location $root
try {
    node --test ops/tests/contracts.mjs
    if ($LASTEXITCODE -ne 0) { throw 'Ops 契约检查失败' }
}
finally { Pop-Location }
