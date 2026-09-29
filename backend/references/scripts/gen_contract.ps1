param(
    [string]$Root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

# 契约由生成而非手工同步：一次写出两端的端点文件（frontend 的 Dart / ops 的 JS）。
# 这两个产物被两端直接编译、运行消费，且仓库没有构建步骤可依赖，因此纳入版本控制。
# 注意：本文件必须保持 UTF-8 with BOM —— Windows PowerShell 5.1 会把无 BOM 的中文注释按 ANSI 解码。
Push-Location $Root
try {
    Write-Host "[contract] exporting endpoints to both clients..."
    go run ./cmd/route_export
}
finally {
    Pop-Location
}
