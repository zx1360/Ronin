#requires -Version 7.0
$ErrorActionPreference = 'Stop'

Push-Location (Split-Path -Parent $PSScriptRoot)
try {
    go test ./internal/config ./internal/handler/ai_handler ./internal/service/review
    if ($LASTEXITCODE -ne 0) { throw '回顾验收失败' }
}
finally { Pop-Location }
