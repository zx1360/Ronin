# 近期回顾接口冒烟：用生产库的**副本** + 临时 STATIC_DIR 起一个临时服务，
# 只读业务数据、不动生产库；跑完删掉副本、临时目录与日志。
# 服务是明文 HTTP 单端口，冒烟用的 `/API/ai/review` 需要 X-API-Key（从 .env 读）。
#
# 注意：本脚本用**临时** STATIC_DIR，因此 ai_config.json 是全新生成的、vlm_model 为空；
# 而自动选定模型的时机是 AI worker 启动（`AI_ENABLED=false` 时不会发生）或网页端显式切换，
# 所以最后一个用例通常走"尚未选定模型"的 400 分支——那也算链路通，用例据此判定。
$ErrorActionPreference = 'Stop'

$root = 'D:\products\Ronin\backend'
$base = Join-Path ([System.IO.Path]::GetTempPath()) ('monarch-review-smoke-' + [guid]::NewGuid().ToString('N'))
$staticDir = Join-Path $base 'static'
$galleryDir = Join-Path $base 'gallery'
$dbFile = Join-Path $base 'monarch_copy.db'
$log = Join-Path $base 'server.log'
$port = 7399            # HTTPS（LOCAL_PORT）
$httpPort = $port + 1   # HTTP（LOCAL_HTTP_PORT）；本脚本的请求一律走明文端口
$proc = $null

# 服务端始终要求 X-API-Key（/API/test 等豁免路径除外），冒烟请求统一带上
$apiKey = ''
foreach ($line in (Get-Content (Join-Path $root '.env') -ErrorAction SilentlyContinue)) {
    if ($line -match '^\s*API_KEY_SERVER\s*=\s*(.+?)\s*$') { $apiKey = $Matches[1] }
}
$authHeaders = @{}
if ($apiKey) { $authHeaders['X-API-Key'] = $apiKey }

function New-Result($name, $ok, $detail) {
    [pscustomobject]@{ Case = $name; Ok = $ok; Detail = $detail }
}

# 流式响应的 body 会是字节数组，统一按 UTF-8 还原。
function Convert-Body($content) {
    if ($content -is [byte[]]) { return [System.Text.Encoding]::UTF8.GetString($content) }
    return [string]$content
}

# pwsh7 的 Invoke-WebRequest 在 4xx/5xx 上抛异常，且异常里的响应内容已被释放；
# 有 -SkipHttpErrorCheck 时直接用，才能拿到服务端返回的可读错误文案。
$skipHttpErrorCheck = (Get-Command Invoke-WebRequest).Parameters.ContainsKey('SkipHttpErrorCheck')

function Invoke-Api {
    param([string]$Method, [string]$Path, $Body, [int]$TimeoutSec = 20)
    $uri = "http://127.0.0.1:$httpPort$Path"
    $extra = @{}
    if ($skipHttpErrorCheck) { $extra['SkipHttpErrorCheck'] = $true }
    try {
        if ($null -eq $Body) {
            $resp = Invoke-WebRequest -Uri $uri -Method $Method -Headers $script:authHeaders -UseBasicParsing -TimeoutSec $TimeoutSec @extra
        }
        else {
            $resp = Invoke-WebRequest -Uri $uri -Method $Method -Headers $script:authHeaders -UseBasicParsing -TimeoutSec $TimeoutSec @extra `
                -ContentType 'application/json' -Body ([System.Text.Encoding]::UTF8.GetBytes((ConvertTo-Json $Body -Depth 6 -Compress)))
        }
        return @{ Status = [int]$resp.StatusCode; Body = (Convert-Body $resp.Content) }
    }
    catch {
        $r = $_.Exception.Response
        if ($null -eq $r) { throw }
        $code = [int]$r.StatusCode
        $text = ''
        try {
            $reader = New-Object System.IO.StreamReader($r.GetResponseStream())
            $text = $reader.ReadToEnd()
        }
        catch { }
        return @{ Status = $code; Body = $text }
    }
}

$results = New-Object System.Collections.ArrayList

try {
    New-Item -ItemType Directory -Path $staticDir, $galleryDir -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $root 'data\monarch.db') -Destination $dbFile

    $env:STATIC_DIR = $staticDir
    $env:GALLERY_DIR = $galleryDir
    $env:DB_FILE = $dbFile
    $env:DB_SCHEMA_FILE = (Join-Path $root 'references\db\sqlite.sql')
    $env:LOCAL_PORT = "$port"          # HTTPS
    $env:LOCAL_HTTP_PORT = "$($port + 1)"   # HTTP（双端口同时监听）
    # 只关掉后台 worker，避免冒烟时拉起侧车进程；Ollama 仍可被对话/回顾按需使用
    $env:AI_ENABLED = 'false'

    $proc = Start-Process -FilePath (Join-Path $root 'cmd.exe') `
        -WorkingDirectory $root -PassThru -WindowStyle Hidden `
        -RedirectStandardOutput $log -RedirectStandardError "$log.err"

    $ready = $false
    for ($i = 0; $i -lt 60; $i++) {
        Start-Sleep -Milliseconds 500
        try {
            $probe = Invoke-WebRequest -Uri "http://127.0.0.1:$httpPort/API/test" -UseBasicParsing -TimeoutSec 3
            if ($probe.StatusCode -eq 200) { $ready = $true; break }
        }
        catch { }
    }
    if (-not $ready) { throw "服务未在 30 秒内就绪，日志见 $log" }

    # 1. 状态接口：AI 关闭时仍应 200 且如实回报 enabled=false
    $status = Invoke-Api -Method GET -Path '/API/ai/status'
    $enabled = $null
    try { $enabled = (ConvertFrom-Json $status.Body).enabled } catch { }
    [void]$results.Add((New-Result 'AI 关闭时 status 仍可用' ($status.Status -eq 200 -and $enabled -eq $false) "HTTP $($status.Status), enabled=$enabled"))

    # 2. 首次读取预设：应生成内置默认值，且落在临时 STATIC_DIR 下
    $first = Invoke-Api -Method GET -Path '/API/ai/review/presets'
    $parsed = ConvertFrom-Json $first.Body
    $presetCount = @($parsed.presets).Count
    $seeded = Test-Path -LiteralPath (Join-Path $staticDir 'data\review_presets.json')
    [void]$results.Add((New-Result '首次读取预设播种内置默认值' `
                ($first.Status -eq 200 -and $presetCount -ge 1 -and $seeded -and "$($parsed.path)".StartsWith($staticDir)) `
                "HTTP $($first.Status), 条数=$presetCount, 文件已生成=$seeded"))

    # 3. 整体替换预设（缺 id 由服务端补齐）
    $payload = @{ presets = @(
            @{ name = '冒烟预设'; role = '你是冒烟测试'; tone = '简洁' },
            @{ name = '第二条'; role = '你是第二条'; tone = '' }
        ) }
    $put = Invoke-Api -Method PUT -Path '/API/ai/review/presets' -Body $payload
    $putBody = ConvertFrom-Json $put.Body
    $ids = @($putBody.presets | ForEach-Object { $_.id })
    $okPut = $put.Status -eq 200 -and @($putBody.presets).Count -eq 2 -and `
        ($ids | Where-Object { $_ }).Count -eq 2 -and ($ids | Select-Object -Unique).Count -eq 2
    [void]$results.Add((New-Result '整体替换预设并补齐 id' $okPut "HTTP $($put.Status), 条数=$(@($putBody.presets).Count)"))

    # 4. 替换结果应落盘并可再次读回
    $again = Invoke-Api -Method GET -Path '/API/ai/review/presets'
    $againCount = @((ConvertFrom-Json $again.Body).presets).Count
    [void]$results.Add((New-Result '预设替换后读回一致' ($again.Status -eq 200 -and $againCount -eq 2) "HTTP $($again.Status), 条数=$againCount"))

    # 5. 非法预设：缺角色应 400 且不改动既有文件
    $bad = Invoke-Api -Method PUT -Path '/API/ai/review/presets' -Body @{ presets = @(@{ name = '缺角色' }) }
    $afterBad = Invoke-Api -Method GET -Path '/API/ai/review/presets'
    $afterBadCount = @((ConvertFrom-Json $afterBad.Body).presets).Count
    [void]$results.Add((New-Result '非法预设返回 400 且不改动' ($bad.Status -eq 400 -and $afterBadCount -eq 2) "HTTP $($bad.Status), 条数=$afterBadCount"))

    # 6. 回顾请求的参数校验
    $cases = @(
        @{ Name = '缺角色返回 400'; Body = @{ days = 7 } },
        @{ Name = '非法日期返回 400'; Body = @{ role = '你是测试'; from = '2026/01/01' } },
        @{ Name = '起止倒置返回 400'; Body = @{ role = '你是测试'; from = '2026-03-10'; to = '2026-03-01' } },
        @{ Name = '抽样条数越界返回 400'; Body = @{ role = '你是测试'; sample_essays = 99 } },
        @{ Name = '天数越界返回 400'; Body = @{ role = '你是测试'; days = 9999 } },
        @{ Name = '角色过长返回 400'; Body = @{ role = ('角' * 1001) } }
    )
    foreach ($item in $cases) {
        $r = Invoke-Api -Method POST -Path '/API/ai/review' -Body $item.Body
        [void]$results.Add((New-Result $item.Name ($r.Status -eq 400) "HTTP $($r.Status)"))
    }

    # 7. 合法请求：模型已选定则产出 stats 事件 + 正文；未选定则 400/503 的可读提示（都算链路通）
    $valid = Invoke-Api -Method POST -Path '/API/ai/review' -TimeoutSec 600 -Body @{
        role = '你是冒烟测试'; tone = '简洁'; days = 30; sample_essays = 2; sample_records = 2
    }
    if ($valid.Status -eq 400 -or $valid.Status -eq 503) {
        [void]$results.Add((New-Result '合法请求（模型未就绪）返回可读提示' $true "HTTP $($valid.Status): $($valid.Body)"))
    }
    else {
        $events = @($valid.Body -split "`n" | Where-Object { $_.Trim() } | ForEach-Object { ConvertFrom-Json $_ })
        $stats = (($events | Where-Object { $_.type -eq 'stats' } | Select-Object -First 1).content)
        $narrative = -join ($events | Where-Object { $_.type -eq 'delta' } | ForEach-Object { $_.content })
        $ok = $valid.Status -eq 200 -and "$stats" -like '*统计范围*' -and `
            "$stats" -like '*【随笔】*' -and "$stats" -like '*【打卡】*' -and $narrative.Trim().Length -gt 20
        [void]$results.Add((New-Result '合法请求产出统计事件与正文' $ok "HTTP $($valid.Status), 事件 $($events.Count) 条, 正文 $($narrative.Length) 字"))
        '---- stats 事件 ----'
        $stats
        '---- 正文（前 240 字）----'
        if ($narrative.Length -gt 240) { $narrative.Substring(0, 240) } else { $narrative }
    }
}
finally {
    if ($proc -and -not $proc.HasExited) { Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue }
    Start-Sleep -Milliseconds 500
    $results | Format-Table -AutoSize -Wrap
    '==== 服务端日志尾部 ===='
    if (Test-Path $log) { Get-Content -LiteralPath $log -Encoding UTF8 -Tail 6 }
    if (Test-Path "$log.err") { Get-Content -LiteralPath "$log.err" -Encoding UTF8 -Tail 6 }
    '==== 清理 ===='
    Get-Process cmd -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq (Join-Path $root 'cmd.exe') } | Stop-Process -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $base -Recurse -Force -ErrorAction SilentlyContinue
    "临时目录已删除: $(-not (Test-Path $base))"
    $failed = @($results | Where-Object { -not $_.Ok }).Count
    "失败用例: $failed / $($results.Count)"
    # 明确的退出码：否则 PowerShell 的非终止错误会让脚本以 1 结束，无法用于自动化
    if ($failed -gt 0) { exit 1 }
    exit 0
}
