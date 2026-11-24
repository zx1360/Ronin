# Ronin 本地 AI 侧车安装脚本
#
# 全部产物都落在本目录内，可随时整体删除回滚：
#   .venv/                侧车虚拟环境
#   models/siglip/        SigLIP 2 双塔 ONNX + 分词器
#   models/buffalo_l/     人脸检测和识别模型
#
# 用法：
#   pwsh -File .\install.ps1

param(
    [string]$Python = "",
    [string]$PipIndex = "https://pypi.tuna.tsinghua.edu.cn/simple",
    [string]$HfEndpoint = "https://hf-mirror.com",
    # SigLIP 2 的多语分词器支持中文查询。
    [string]$HfRepo = "onnx-community/siglip2-base-patch16-224-ONNX",
    [string]$BuffaloRepo = "public-data/insightface",
    [switch]$SkipModels,
    [switch]$Recreate
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$ProgressPreference = "SilentlyContinue"

$Root = $PSScriptRoot
$VenvDir = Join-Path $Root ".venv"
$VenvPython = Join-Path $VenvDir "Scripts\python.exe"
$ModelsDir = Join-Path $Root "models"
$SiglipDir = Join-Path $ModelsDir "siglip"
$Env:PYTHONIOENCODING = "utf-8"

function Write-Step([string]$Message) {
    Write-Host "[install] $Message" -ForegroundColor Cyan
}

function Invoke-Python([string]$Executable) {
    & $Executable @args
    if ($LASTEXITCODE -ne 0) {
        throw "Python 命令失败（exit $LASTEXITCODE）: $Executable $args"
    }
}

function Remove-Venv([string]$Path) {
    $target = Get-Item -LiteralPath $Path
    if ($target.Parent.FullName -ne $Root -or ($target.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
        throw "虚拟环境必须是侧车目录下的普通目录: $Path"
    }
    Remove-Item -LiteralPath $target.FullName -Recurse -Force
}

$backup = $null
try {
    if ($Recreate -or -not (Test-Path -LiteralPath $VenvPython -PathType Leaf)) {
        if (-not $Python) {
            $localPython = Join-Path $Root ".python\python.exe"
            $Python = if (Test-Path -LiteralPath $localPython -PathType Leaf) { $localPython } else { "python" }
        }
        Invoke-Python $Python -c "import ensurepip, venv"
        if ($Recreate -and (Test-Path -LiteralPath $VenvDir)) {
            $backupName = ".venv.$([guid]::NewGuid().ToString('N')).bak"
            Rename-Item -LiteralPath $VenvDir -NewName $backupName
            $backup = Join-Path $Root $backupName
        }
        Write-Step "用 $Python 创建虚拟环境 $VenvDir"
        Invoke-Python $Python -m venv $VenvDir
    }
    Write-Step "使用解释器: $VenvPython"
    try {
        Invoke-Python $VenvPython --version
    }
    catch {
        throw "侧车虚拟环境无法启动。请用兼容的基础 Python 运行 install.ps1 -Recreate，必要时通过 -Python 指定路径。`n$($_.Exception.Message)"
    }
    # 互斥发行版共享包目录，成对卸载后再让 pip 重装。
    $packages = Invoke-Python $VenvPython -m pip --disable-pip-version-check list --format=json | ConvertFrom-Json
    if ($packages.name -contains "opencv-python-headless") {
        Invoke-Python $VenvPython -m pip uninstall -y opencv-python-headless opencv-python
    }
    if ($packages.name -contains "onnxruntime") {
        Invoke-Python $VenvPython -m pip uninstall -y onnxruntime onnxruntime-directml
    }
    Write-Step "安装侧车依赖"
    Invoke-Python $VenvPython -m pip install -r (Join-Path $Root "requirements.txt") --index-url $PipIndex
    Invoke-Python $VenvPython -m pip check
    if ($SkipModels) {
        Push-Location $Root
        try { Invoke-Python $VenvPython -m ronin_ai --probe }
        finally { Pop-Location }
    }
}
catch {
    if ($backup) {
        if (Test-Path -LiteralPath $VenvDir) {
            Remove-Venv $VenvDir
        }
        Rename-Item -LiteralPath $backup -NewName '.venv'
    }
    throw
}
if ($backup) {
    Remove-Venv $backup
}

if ($SkipModels) {
    exit 0
}

# SigLIP 2 模型

Write-Step "下载 SigLIP 2 模型到 $SiglipDir"
New-Item -ItemType Directory -Path $SiglipDir -Force | Out-Null

$siglipFiles = @(
    @{ Remote = "onnx/vision_model_quantized.onnx"; Local = "vision_model_quantized.onnx" },
    @{ Remote = "onnx/text_model_quantized.onnx"; Local = "text_model_quantized.onnx" },
    @{ Remote = "tokenizer.json"; Local = "tokenizer.json" },
    @{ Remote = "preprocessor_config.json"; Local = "preprocessor_config.json" }
)
foreach ($file in $siglipFiles) {
    $target = Join-Path $SiglipDir $file.Local
    if ((Test-Path -LiteralPath $target) -and ((Get-Item -LiteralPath $target).Length -gt 1KB)) {
        Write-Step "已存在，跳过: $($file.Local)"
        continue
    }
    Write-Step "下载 $($file.Local)"
    Invoke-WebRequest -Uri "$HfEndpoint/$HfRepo/resolve/main/$($file.Remote)" -OutFile $target -TimeoutSec 1800
}

# buffalo_l 检测和识别模型
$BuffaloDir = Join-Path $ModelsDir "buffalo_l"
New-Item -ItemType Directory -Path $BuffaloDir -Force | Out-Null

foreach ($name in @("det_10g.onnx", "w600k_r50.onnx")) {
    $target = Join-Path $BuffaloDir $name
    if ((Test-Path -LiteralPath $target) -and ((Get-Item -LiteralPath $target).Length -gt 1MB)) {
        Write-Step "已存在，跳过: $name"
        continue
    }
    Write-Step "下载 $name"
    Invoke-WebRequest -Uri "$HfEndpoint/$BuffaloRepo/resolve/main/models/buffalo_l/$name" -OutFile $target -TimeoutSec 3600
}

Write-Step "预热 RapidOCR"
Push-Location $Root
try {
    Invoke-Python $VenvPython -c "from rapidocr import RapidOCR; RapidOCR(); print('rapidocr ready')"
}
catch { Write-Warning "RapidOCR 预热失败（首次 OCR 任务会再尝试）: $($_.Exception.Message)" }
finally { Pop-Location }

Write-Step "探测结果："
Push-Location $Root
try { Invoke-Python $VenvPython -m ronin_ai --probe }
finally { Pop-Location }

Write-Step "完成。Monarch 会在有任务时按需拉起侧车，空闲后自动退出。"
