param(
    [string]$Root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function Ensure-Directory {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -ItemType Directory -Path $Path | Out-Null
    }
}

function Ensure-Swag {
    $goBin = Join-Path (go env GOPATH) "bin"
    if (-not (($env:Path -split ';') -contains $goBin)) {
        $env:Path = "$goBin;$env:Path"
    }

    if (-not (Get-Command swag -ErrorAction SilentlyContinue)) {
        Write-Host "[refs] swag not found, installing github.com/swaggo/swag/cmd/swag@latest"
        go install github.com/swaggo/swag/cmd/swag@latest
    }

    if (-not (Get-Command swag -ErrorAction SilentlyContinue)) {
        throw "swag command not found after installation"
    }
}

function Join-ByteArrays {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][byte[]]$First,
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][byte[]]$Second
    )

    $joined = New-Object byte[] ($First.Length + $Second.Length)
    [Array]::Copy($First, 0, $joined, 0, $First.Length)
    [Array]::Copy($Second, 0, $joined, $First.Length, $Second.Length)
    return $joined
}

function Capture-HelpSnapshot {
    param(
        [Parameter(Mandatory = $true)][string]$WorkingDir,
        [Parameter(Mandatory = $true)][string]$OutPath,
        [Parameter(Mandatory = $true)][string]$Command,
        [Parameter(Mandatory = $true)][string[]]$Args
    )

    $stdoutFile = [System.IO.Path]::GetTempFileName()
    $stderrFile = [System.IO.Path]::GetTempFileName()

    try {
        $process = Start-Process -FilePath $Command -ArgumentList $Args -WorkingDirectory $WorkingDir -Wait -PassThru -NoNewWindow -RedirectStandardOutput $stdoutFile -RedirectStandardError $stderrFile

        $stdoutBytes = [System.IO.File]::ReadAllBytes($stdoutFile)
        $stderrBytes = [System.IO.File]::ReadAllBytes($stderrFile)
        $allBytes = Join-ByteArrays -First $stdoutBytes -Second $stderrBytes
        $text = [System.Text.Encoding]::UTF8.GetString($allBytes).TrimEnd()
        if ([string]::IsNullOrWhiteSpace($text)) {
            $text = "(no output)"
        }

        Ensure-Directory -Path (Split-Path -Parent $OutPath)

        $cmdLine = "$Command $($Args -join ' ')"
        $content = @(
            "# CLI Help Snapshot",
            "",
            "- GeneratedAt: $(Get-Date -Format 'yyyy-MM-ddTHH:mm:ssK')",
            "- WorkingDir: $WorkingDir",
            "- Command: $cmdLine",
            "- ExitCode: $($process.ExitCode)",
            "",
            '```text',
            $text,
            '```',
            ""
        ) -join "`n"

        Set-Content -LiteralPath $OutPath -Value $content -Encoding UTF8

        if ($process.ExitCode -ne 0) {
            throw "Command failed with exit code $($process.ExitCode): $cmdLine"
        }
    }
    finally {
        if (Test-Path -LiteralPath $stdoutFile) {
            Remove-Item -LiteralPath $stdoutFile -Force
        }
        if (Test-Path -LiteralPath $stderrFile) {
            Remove-Item -LiteralPath $stderrFile -Force
        }
    }
}

$apiDir = Join-Path $Root "references\api"
$cliDir = Join-Path $Root "references\cli"

Ensure-Directory -Path $apiDir
Ensure-Directory -Path $cliDir

Push-Location $Root
try {
    Ensure-Swag

    Write-Host "[refs] generating openapi (swagger.json + swagger.yaml)..."
    swag init -g main.go -d cmd,internal/handler/comic_handler,internal/handler/data_handler,internal/handler/gallery_handler,internal/handler/util_handler,internal/model -o references/api/openapi --outputTypes json,yaml

    Write-Host "[refs] exporting router snapshot..."
    go run ./cmd/route_export -json references/api/routes.json -md references/api/routes.md

    Write-Host "[refs] capturing CLI snapshots..."
    Capture-HelpSnapshot -WorkingDir $Root -OutPath (Join-Path $cliDir "monarch-main.md") -Command "go" -Args @("run", "./cmd/main.go", "-h")

    $gizmosRoot = Join-Path $Root "gizmos"
    Capture-HelpSnapshot -WorkingDir $gizmosRoot -OutPath (Join-Path $cliDir "gizmos-gallery.md") -Command "go" -Args @("run", "./cmd/gallery", "-h")
    Capture-HelpSnapshot -WorkingDir $gizmosRoot -OutPath (Join-Path $cliDir "gizmos-comic-indexer.md") -Command "go" -Args @("run", "./cmd/comic_indexer", "-h")

    Write-Host "[refs] done"
}
finally {
    Pop-Location
}
