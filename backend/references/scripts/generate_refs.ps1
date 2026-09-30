# 生成跨端契约快照（路由表 + CLI 帮助）。
#
# 真源永远是 Go 代码，任何时刻重跑本脚本即可得到最新契约。
# 输出统一落在 references/generated/ 下，repositories 里只需维护本脚本。
#
#   .\generate_refs.ps1          生成/刷新 references/generated/
#   .\generate_refs.ps1 -Check   只校验磁盘上的快照是否与当前代码一致，不写文件（验收用）
param(
    [string]$Root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path,
    [switch]$Check
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$relApiDir = "references\generated\api"
$relCliDir = "references\generated\cli"

function Ensure-Directory {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -ItemType Directory -Path $Path | Out-Null
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

# 命令的 -h 输出。快照里只留相对命令与退出码，不留时间戳/绝对路径，保证可重复生成。
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
        # go run 把产物放在随机临时目录，flag 包又打印 os.Args[0]，该行含机器相关的绝对路径；
        # 归一化掉才能重复生成出相同快照。
        $text = ([System.Text.Encoding]::UTF8.GetString($allBytes) -replace '(?m)^Usage of .*:$', 'Usage of <binary>:').TrimEnd()
        if ([string]::IsNullOrWhiteSpace($text)) {
            $text = "(no output)"
        }

        Ensure-Directory -Path (Split-Path -Parent $OutPath)

        $cmdLine = "$Command $($Args -join ' ')"
        $content = @(
            "# CLI Help Snapshot",
            "",
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

function Invoke-Generation {
    param([Parameter(Mandatory = $true)][string]$OutRoot)

    $apiDir = Join-Path $OutRoot $relApiDir
    $cliDir = Join-Path $OutRoot $relCliDir
    Ensure-Directory -Path $apiDir
    Ensure-Directory -Path $cliDir

    Push-Location $Root
    try {
        Write-Host "[refs] exporting router snapshot..."
        go run ./cmd/route_export -json (Join-Path $apiDir "routes.json") -md (Join-Path $apiDir "routes.md")

        Write-Host "[refs] capturing CLI snapshots..."
        Capture-HelpSnapshot -WorkingDir $Root -OutPath (Join-Path $cliDir "monarch-main.md") -Command "go" -Args @("run", "./cmd/main.go", "-h")

        $gizmosRoot = Join-Path $Root "gizmos"
        Capture-HelpSnapshot -WorkingDir $gizmosRoot -OutPath (Join-Path $cliDir "gizmos-gallery.md") -Command "go" -Args @("run", "./cmd/gallery", "-h")
    }
    finally {
        Pop-Location
    }
}

# 逐文件比对两棵目录树，返回不一致的相对路径。
function Compare-Tree {
    param(
        [Parameter(Mandatory = $true)][string]$Expected,
        [Parameter(Mandatory = $true)][string]$Actual
    )

    $diffs = @()
    $expectedFiles = @()
    if (Test-Path -LiteralPath $Expected) {
        $expectedFiles = Get-ChildItem -LiteralPath $Expected -Recurse -File | ForEach-Object { $_.FullName.Substring($Expected.Length).TrimStart('\') }
    }

    foreach ($rel in $expectedFiles) {
        $actualPath = Join-Path $Actual $rel
        $expectedPath = Join-Path $Expected $rel
        if (-not (Test-Path -LiteralPath $actualPath)) {
            $diffs += "$rel (缺失)"
            continue
        }
        $a = (Get-FileHash -LiteralPath $expectedPath -Algorithm SHA256).Hash
        $b = (Get-FileHash -LiteralPath $actualPath -Algorithm SHA256).Hash
        if ($a -ne $b) {
            $diffs += "$rel (内容不一致)"
        }
    }

    if (Test-Path -LiteralPath $Actual) {
        foreach ($file in (Get-ChildItem -LiteralPath $Actual -Recurse -File)) {
            $rel = $file.FullName.Substring($Actual.Length).TrimStart('\')
            if ($expectedFiles -notcontains $rel) {
                $diffs += "$rel (多余)"
            }
        }
    }

    return $diffs
}

if ($Check) {
    $generatedDir = Join-Path $Root "references\generated"
    if (-not (Test-Path -LiteralPath $generatedDir)) {
        throw "快照目录不存在：$generatedDir；先运行不带 -Check 的本脚本生成一次。"
    }

    $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("refs-check-" + [guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Path $tempRoot | Out-Null
    try {
        Invoke-Generation -OutRoot $tempRoot
        $diffs = @(Compare-Tree -Expected $generatedDir -Actual (Join-Path $tempRoot "references\generated"))
        if ($diffs.Count -gt 0) {
            Write-Host "[refs] 快照与代码不一致：" -ForegroundColor Red
            $diffs | ForEach-Object { Write-Host "  - $_" }
            throw "契约快照已过期，请重新运行 $($MyInvocation.MyCommand.Name)"
        }
        Write-Host "[refs] check ok"
    }
    finally {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
}
else {
    Invoke-Generation -OutRoot $Root
    Write-Host "[refs] done -> references/generated/"
}
