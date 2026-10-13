# NSCA-FitMotion 启动脚本（Windows）  /  Launcher for Windows
# 在本机 localhost:8765 启动一个只给自己用的小服务器，并用浏览器打开页面。
# 为什么需要：直接双击 HTML 时，浏览器会拒绝页面里的摄像头请求；通过 localhost 打开就没问题。
# 端口固定为 8765：浏览器的数据按“网址+端口”保存，换端口等于换了一个存储空间，之前的数据会“看不见”。
# 不需要安装 Python，使用 Windows 自带的 PowerShell。

$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}

$Port = 8765
$File = 'NSCA-FitMotion.html'
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$Path = Join-Path $Root $File
$Url  = "http://localhost:$Port/$File"

if (-not (Test-Path -LiteralPath $Path)) {
    Write-Host "找不到 $File 。请确认本脚本与它在同一个文件夹里。 (File not found: $File)"
    exit 1
}

# 已经有一个本程序的服务在运行？直接打开浏览器即可
function Test-Ours {
    try {
        $r = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 2
        return ($r.Content -match 'NSCA')
    } catch { return $false }
}
if (Test-Ours) {
    Write-Host "服务已经在运行，直接打开浏览器。 (Already running)"
    Start-Process $Url
    exit 0
}

$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://localhost:$Port/")
try {
    $listener.Start()
} catch {
    Write-Host "端口 $Port 已被别的程序占用，或无法监听。 (Port $Port is busy or cannot be opened)"
    Write-Host "请先关闭占用该端口的程序再重试。不要改用别的端口：换端口之前的数据会看不见。"
    Write-Host $_.Exception.Message
    exit 1
}

Write-Host "============================================================"
Write-Host " NSCA-FitMotion 已启动 / started"
Write-Host " $Url"
Write-Host " 关闭此窗口即可停止服务。 (Close this window to stop)"
Write-Host "============================================================"
Start-Process $Url

try {
    while ($listener.IsListening) {
        $ctx = $listener.GetContext()
        $res = $ctx.Response
        try {
            $p = $ctx.Request.Url.AbsolutePath
            if ($ctx.Request.HttpMethod -eq 'GET' -and ($p -eq '/' -or $p -eq "/$File")) {
                $bytes = [System.IO.File]::ReadAllBytes($Path)      # 每次都重新读取，替换文件后刷新页面即可
                $res.ContentType = 'text/html; charset=utf-8'
                $res.ContentLength64 = $bytes.Length
                $res.OutputStream.Write($bytes, 0, $bytes.Length)
            } else {
                $res.StatusCode = 404
            }
        } catch {
            # 浏览器中途断开等情况：忽略，继续服务
        } finally {
            try { $res.Close() } catch {}
        }
    }
} finally {
    $listener.Stop()
}
