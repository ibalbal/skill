#!/usr/bin/env pwsh
<#
.SYNOPSIS
    视频学习处理脚本 - 提取帧、音频、转录语音

.DESCRIPTION
    自动检测系统环境，从视频中提取关键帧和音频，
    使用 Whisper 转录语音，生成学习素材。

.PARAMETER Video
    视频文件路径（必填）

.PARAMETER Output
    输出目录路径（可选，默认为视频同目录下的 _output 文件夹）

.PARAMETER Proxy
    代理地址，用于下载 Whisper 模型（可选）

.PARAMETER Model
    Whisper 模型大小：tiny, base, small, medium, large（默认：small）

.PARAMETER Language
    语言代码：zh, en, ja, ko...（默认：zh）

.PARAMETER FrameInterval
    帧提取间隔（秒），默认 30

.EXAMPLE
    .\process_video.ps1 -Video "C:\videos\lesson.mp4"
    
.EXAMPLE
    .\process_video.ps1 -Video "video.mp4" -Proxy "http://127.0.0.1:6666" -Model medium
    
.EXAMPLE
    .\process_video.ps1 -Video "video.mp4" -Output "C:\output" -FrameInterval 60
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$Video,
    
    [string]$Output,
    
    [string]$Proxy,
    
    [ValidateSet("tiny", "base", "small", "medium", "large")]
    [string]$Model = "small",
    
    [string]$Language = "zh",
    
    [int]$FrameInterval = 30
)

# ========== 环境检测 ==========

function Find-Command {
    param([string]$Name)
    $cmd = Get-Command $Name -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    return $null
}

function Find-Python {
    # 优先检查受信目录
    $trustedPaths = @(
        "C:\Dev\Python\python.exe",
        "/usr/bin/python3",
        "/usr/local/bin/python3"
    )
    
    foreach ($p in $trustedPaths) {
        if (Test-Path $p) { return $p }
    }
    
    # 检查系统 Python
    $python = Find-Command "python"
    if ($python) { return $python }
    
    $python3 = Find-Command "python3"
    if ($python3) { return $python3 }
    
    # Windows AppData 路径
    $winPython = Join-Path $env:LOCALAPPDATA "Programs\Python\Python312\python.exe"
    if (Test-Path $winPython) { return $winPython }
    
    return $null
}

function Find-FFmpeg {
    $ffmpeg = Find-Command "ffmpeg"
    if ($ffmpeg) { return $ffmpeg }
    
    # Windows winget 安装路径
    $wingetPath = Join-Path $env:LOCALAPPDATA "Microsoft\WinGet\Packages"
    $ffmpegDir = Get-ChildItem $wingetPath -Filter "*ffmpeg*" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($ffmpegDir) {
        $ffmpegExe = Join-Path $ffmpegDir.FullName "ffmpeg-*_build\bin\ffmpeg.exe"
        $found = Get-ChildItem (Split-Path $ffmpegExe -Parent) -Filter "ffmpeg.exe" -ErrorAction SilentlyContinue
        if ($found) { return $found.FullName }
    }
    
    return $null
}

# 检测工具
$ffmpeg = Find-FFmpeg
$ffprobe = $ffmpeg -replace "ffmpeg", "ffprobe"
$python = Find-Python

Write-Host "=== 环境检测 ===" -ForegroundColor Cyan
Write-Host "ffmpeg:  $(if($ffmpeg){$ffmpeg}else{'未找到'})"
Write-Host "ffprobe: $(if($ffprobe){$ffprobe}else{'未找到'})"
Write-Host "python:  $(if($python){$python}else{'未找到'})"
Write-Host ""

if (-not $ffmpeg -or -not $python) {
    Write-Host "缺少必要工具，请先安装：" -ForegroundColor Red
    if (-not $ffmpeg) { Write-Host "  ffmpeg: winget install Gyan.FFmpeg" }
    if (-not $python) { Write-Host "  Python: https://python.org/downloads" }
    exit 1
}

# ========== 路径处理 ==========

$Video = (Resolve-Path $Video -ErrorAction Stop).Path
$videoName = [System.IO.Path]::GetFileNameWithoutExtension($Video)
$videoDir = Split-Path $Video -Parent

if (-not $Output) {
    $Output = Join-Path $videoDir "${videoName}_output"
}

$framesDir = Join-Path $Output "frames"
$audioFile = Join-Path $Output "audio.wav"
$transcriptFile = Join-Path $Output "transcript.txt"

# 创建目录
New-Item -ItemType Directory -Force -Path $framesDir | Out-Null
New-Item -ItemType Directory -Force -Path $Output | Out-Null

Write-Host "输出目录: $Output" -ForegroundColor Green

# ========== 获取视频信息 ==========

Write-Host "`n=== 获取视频信息 ===" -ForegroundColor Cyan

$videoInfo = & $ffprobe -v quiet -print_format json -show_format -show_streams $Video 2>$null | ConvertFrom-Json
$duration = [double]$videoInfo.format.duration
$width = $videoInfo.streams | Where-Object { $_.codec_type -eq "video" } | Select-Object -First 1 -ExpandProperty width
$height = $videoInfo.streams | Where-Object { $_.codec_type -eq "video" } | Select-Object -First 1 -ExpandProperty height

Write-Host "时长: $([int]$duration) 秒"
Write-Host "分辨率: ${width}x${height}"

# ========== 提取视频帧 ==========

Write-Host "`n=== 提取视频帧 ===" -ForegroundColor Cyan

# 计算时间点
$timePoints = @()
for ($t = 0; $t -lt $duration; $t += $FrameInterval) {
    $timePoints += $t
}
# 添加最后一个时间点（90%位置）
$lastPoint = [int]($duration * 0.9)
if ($lastPoint -notin $timePoints) {
    $timePoints += $lastPoint
}

$frameCount = 0
foreach ($t in $timePoints) {
    $frameCount++
    $timeStr = "{0:D2}m{1:D2}s" -f ([int]($t / 60)), ([int]($t % 60))
    $frameFile = Join-Path $framesDir "frame_${timeStr}.png"
    
    Write-Host "  提取 $timeStr ..." -NoNewline
    & $ffmpeg -y -ss $t -i $Video -vframes 1 -q:v 2 $frameFile 2>$null | Out-Null
    if ($?) { Write-Host " OK" -ForegroundColor Green } else { Write-Host " 失败" -ForegroundColor Red }
}

Write-Host "共提取 $frameCount 帧" -ForegroundColor Green

# ========== 提取音频 ==========

Write-Host "`n=== 提取音频 ===" -ForegroundColor Cyan

Write-Host "  提取音频 ..." -NoNewline
& $ffmpeg -y -i $Video -vn -acodec pcm_s16le -ar 16000 -ac 1 $audioFile 2>$null | Out-Null
if ($?) { Write-Host " OK" -ForegroundColor Green } else { Write-Host " 失败" -ForegroundColor Red }

# ========== 检查 Whisper ==========

Write-Host "`n=== 检查 Whisper ===" -ForegroundColor Cyan

$whisperInstalled = & $python -c "import whisper; print('ok')" 2>$null
if ($whisperInstalled -ne "ok") {
    Write-Host "Whisper 未安装，正在安装..." -ForegroundColor Yellow
    
    $pipArgs = @("-m", "pip", "install", "openai-whisper")
    if ($Proxy) {
        $pipArgs += "--proxy", $Proxy
    }
    
    & $python @pipArgs
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Whisper 安装失败" -ForegroundColor Red
        Write-Host "请手动安装: pip install openai-whisper"
        exit 1
    }
}

Write-Host "Whisper 已安装" -ForegroundColor Green

# ========== 转录音频 ==========

Write-Host "`n=== 转录音频 ===" -ForegroundColor Cyan
Write-Host "模型: $Model, 语言: $Language"
Write-Host "注意：首次使用会下载模型，请耐心等待..."

$scriptDir = Split-Path $MyInvocation.MyCommand.Path -Parent
$transcribeScript = Join-Path $scriptDir "transcribe.py"

# 设置环境变量
$env:PYTHONIOENCODING = "utf-8"
if ($Proxy) {
    $env:HTTP_PROXY = $Proxy
    $env:HTTPS_PROXY = $Proxy
}

& $python $transcribeScript $audioFile $transcriptFile $Model $Language

if ($LASTEXITCODE -eq 0) {
    Write-Host "`n转录完成！" -ForegroundColor Green
} else {
    Write-Host "`n转录失败" -ForegroundColor Red
    exit 1
}

# ========== 完成 ==========

Write-Host @"

=== 处理完成 ===
输出文件:
  视频帧: $framesDir (共 $frameCount 帧)
  音频:   $audioFile
  转录:   $transcriptFile

下一步:
  1. 使用视觉模型分析 frames 目录下的图片
  2. 结合 transcript.txt 的内容生成学习笔记
"@ -ForegroundColor Green
