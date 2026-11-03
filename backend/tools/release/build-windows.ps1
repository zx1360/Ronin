#Requires -Version 7
param([string]$Output = "$PSScriptRoot/../../dist/Ronin-Windows-x64.zip")

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true
$repo = (Resolve-Path "$PSScriptRoot/../../..").Path
$outputPath = [IO.Path]::GetFullPath($Output)
if (Test-Path -LiteralPath $outputPath) { throw "输出已存在：$outputPath" }
New-Item -ItemType Directory -Path (Split-Path -Parent $outputPath) -Force | Out-Null
$tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
$stage = [IO.Directory]::CreateTempSubdirectory('ronin-release-').FullName

try {
    $backend = "$stage/backend"
    New-Item -ItemType Directory -Path "$backend/gizmos" -Force | Out-Null
    $env:GOOS = 'windows'
    $env:GOARCH = 'amd64'
    $env:CGO_ENABLED = '0'
    go -C "$repo/backend" build -trimpath -ldflags '-s -w' -o "$backend/Monarch.exe" ./cmd
    go -C "$repo/backend/gizmos" build -trimpath -ldflags '-s -w' -o "$backend/gizmos/gallery.exe" ./cmd/gallery

    $files = git -C $repo ls-files -- ops/web backend/gizmos/comix backend/tools/ai
    $files = $files | Where-Object {
        $_ -match '^ops/web/' -or
        $_ -match '^backend/gizmos/comix/(comix/.+\.py|util/.+\.py|requirements\.txt)$' -or
        $_ -match '^backend/tools/ai/(ronin_ai/.+\.py|install\.ps1|requirements\.txt|README\.md)$'
    }
    foreach ($file in ($files + @('backend/references/db/sqlite.sql', 'LICENSE'))) {
        $target = Join-Path $stage $file
        New-Item -ItemType Directory -Path (Split-Path -Parent $target) -Force | Out-Null
        Copy-Item -LiteralPath (Join-Path $repo $file) -Destination $target
    }
    New-Item -ItemType Directory -Path "$stage/ops/web/vendor" | Out-Null
    Copy-Item -LiteralPath "$repo/ops/web/vendor/vue.esm-browser.prod.js" -Destination "$stage/ops/web/vendor"
    foreach ($path in 'gallery/Raw', 'static/comics') {
        New-Item -ItemType Directory -Path "$backend/$path" -Force | Out-Null
    }

    @"
STATIC_DIR=static
GALLERY_DIR=gallery
LOCAL_PORT=7274
LOCAL_HTTP_PORT=7275
API_KEY_SERVER=auto
GIN_MODE=release
COMIX_ROOT=gizmos/comix
COMIX_PYTHON=gizmos/comix/.venv/Scripts/python.exe
COMIC_STORAGE_ROOT=static/comics
AI_AUTO_CAPS=phash
"@ | Set-Content -LiteralPath "$backend/.env" -Encoding ascii
    @"
@echo off
setlocal
cd /d "%~dp0backend" || exit /b 1
for %%V in (STATIC_DIR GALLERY_DIR DB_FILE DB_SCHEMA_FILE GALLERY_CLI OPS_WEB_DIR COMIX_ROOT COMIX_PYTHON COMIC_STORAGE_ROOT API_KEY_SERVER LOCAL_PORT LOCAL_HTTP_PORT) do set "%%V="
echo Northstar: http://127.0.0.1:7275/ops/
".\Monarch.exe"
if errorlevel 1 pause
"@ | Set-Content -LiteralPath "$stage/Start Ronin.cmd" -Encoding ascii
    Copy-Item -LiteralPath "$PSScriptRoot/使用说明.md" -Destination "$stage/使用说明.md"
    [IO.Compression.ZipFile]::CreateFromDirectory($stage, $outputPath)
    Write-Output $outputPath
}
finally {
    $resolved = (Resolve-Path -LiteralPath $stage).Path
    if ([IO.Path]::GetDirectoryName($resolved) -eq [IO.Path]::TrimEndingDirectorySeparator($tempRoot) -and
        [IO.Path]::GetFileName($resolved).StartsWith('ronin-release-')) {
        Remove-Item -LiteralPath $resolved -Recurse -Force
    }
}
