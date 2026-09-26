# Ronin 本地 AI 侧车安装脚本
#
# 全部产物都落在本目录内，可随时整体删除回滚：
#   .venv/                独立虚拟环境
#   models/siglip/        SigLIP 2 双塔 ONNX + 分词器（约 200MB）
#   models/buffalo_l/     人脸检测/识别模型（约 183MB）
#
# 用法：
#   powershell -ExecutionPolicy Bypass -File .\install.ps1
#   powershell -ExecutionPolicy Bypass -File .\install.ps1 -SkipModels   # 只装 python 依赖

param(
    # 默认走清华镜像：直连 pypi.org 在本机实测只有 ~40KB/s，装完要一个多小时。
    # 如需官方源：-PipIndex https://pypi.org/simple
    [string]$PipIndex = "https://pypi.tuna.tsinghua.edu.cn/simple",
    [string]$HfEndpoint = "https://hf-mirror.com",
    # SigLIP 2：与 SigLIP 1 同构（视觉/文本双塔 + tokenizer.json），但分词器是
    # Gemma 的 25.6 万词表多语版本。SigLIP 1 的 3.2 万词表**不支持中文**，
    # 中文查询会整体退化成 <unk>，语义搜索直接失效。
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
$ModelsDir = Join-Path $Root "models"
$SiglipDir = Join-Path $ModelsDir "siglip"
$Env:PYTHONIOENCODING = "utf-8"

function Write-Step([string]$Message) {
    Write-Host "[install] $Message" -ForegroundColor Cyan
}

function Get-VenvPython {
    $candidate = Join-Path $VenvDir "Scripts\python.exe"
    if (-not (Test-Path -LiteralPath $candidate)) {
        throw "虚拟环境未创建成功: $candidate"
    }
    return $candidate
}

# 运行 python 并合并 stderr。
#
# Windows PowerShell 会把原生命令写到 stderr 的每一行都变成 NativeCommandError，
# 在 $ErrorActionPreference=Stop 下直接中断脚本（pip / rapidocr 都会往 stderr 打
# 正常日志）。这里临时放宽首选项并显式回传退出码，由调用方决定如何处理。
function Invoke-Python {
    param([Parameter(Mandatory = $true)][string[]]$Arguments)

    $previous = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        & $Python @Arguments 2>&1 | ForEach-Object { Write-Host "  $_" }
        return $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previous
    }
}

# ---------- 1. 虚拟环境 ----------

if ($Recreate -and (Test-Path -LiteralPath $VenvDir)) {
    Write-Step "删除已有虚拟环境"
    Remove-Item -LiteralPath $VenvDir -Recurse -Force
}

if (-not (Test-Path -LiteralPath (Join-Path $VenvDir "Scripts\python.exe"))) {
    Write-Step "创建虚拟环境 $VenvDir"
    python -m venv $VenvDir
}
$Python = Get-VenvPython
Write-Step "使用解释器: $Python"

[void](Invoke-Python @("--version"))
[void](Invoke-Python @("-m", "pip", "install", "--upgrade", "pip", "--index-url", $PipIndex, "--quiet"))

# ---------- 2. python 依赖 ----------

# 互斥发行版必须"成对卸载再重装"：它们共用同一个包目录（cv2 / onnxruntime），
# 卸载任一个都会连带走掉另一份的文件；而 pip 只看 dist-info，之后仍认为剩下的
# 那个"已满足"而拒绝补文件，模块就残废了。所以两个一起卸，交给下面的 install 重装。
$ErrorActionPreference = "Continue"
& $Python -m pip show opencv-python-headless *> $null
$hasHeadless = ($LASTEXITCODE -eq 0)
& $Python -m pip show onnxruntime *> $null
$hasCpuOrt = ($LASTEXITCODE -eq 0)
$ErrorActionPreference = "Stop"

if ($hasHeadless) {
    Write-Step "清理与 opencv-python 冲突的 opencv-python-headless"
    [void](Invoke-Python @("-m", "pip", "uninstall", "-y", "opencv-python-headless", "opencv-python"))
}

if ($hasCpuOrt) {
    Write-Step "清理与 onnxruntime-directml 冲突的 CPU 版 onnxruntime"
    [void](Invoke-Python @("-m", "pip", "uninstall", "-y", "onnxruntime", "onnxruntime-directml"))
}

Write-Step "安装依赖（onnxruntime-directml / opencv / tokenizers / rapidocr，约 250MB 下载）"
$pipExit = Invoke-Python @("-m", "pip", "install", "-r", (Join-Path $Root "requirements.txt"), "--index-url", $PipIndex)
if ($pipExit -ne 0) {
    throw "pip 安装依赖失败（exit $pipExit）"
}

if ($SkipModels) {
    Write-Step "-SkipModels 已指定，跳过模型下载"
    Push-Location $Root
    try { [void](Invoke-Python @("-m", "ronin_ai", "--probe")) }
    finally { Pop-Location }
    exit 0
}

# ---------- 3. SigLIP 模型 ----------

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

# ---------- 4. 人脸模型 buffalo_l（只取检测与识别两个） ----------

# 逐个文件从 HF 镜像下载，而不是拉 GitHub Release 的整包：
# 一是 GitHub 直连实测只有 ~1.5MB/分钟，二是整包里的 3D/年龄性别模型我们用不到。
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

# ---------- 5. 预热 OCR（rapidocr 初始化时校验模型） ----------

Write-Step "预热 RapidOCR"
Push-Location $Root
try {
    $ocrExit = Invoke-Python @("-c", "from rapidocr import RapidOCR; RapidOCR(); print('rapidocr ready')")
    if ($ocrExit -ne 0) {
        Write-Warning "RapidOCR 预热失败（首次 OCR 任务会再尝试）"
    }
}
finally { Pop-Location }

# ---------- 6. 校验 ----------

Write-Step "探测结果："
Push-Location $Root
try { [void](Invoke-Python @("-m", "ronin_ai", "--probe")) }
finally { Pop-Location }

Write-Step "完成。Monarch 会在有任务时按需拉起侧车，空闲后自动退出。"
