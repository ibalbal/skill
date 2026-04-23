#Requires -Version 5.1
<#
.SYNOPSIS
    Video Learner - Extract frames, audio, and transcribe videos

.DESCRIPTION
    Automatically detect system environment, extract key frames and audio from videos,
    and transcribe speech using Whisper.

    Optimized v2.1:
    - Smart frame extraction (scene detection or fixed interval)
    - Chinese mirror support for model downloading
    - Better proxy handling

.PARAMETER Video
    Video file path (required)

.PARAMETER Output
    Output directory (default: video同目录下的 _video_learn)

.PARAMETER Proxy
    Proxy address for downloading Whisper models (optional)

.PARAMETER Mirror
    Chinese mirror for model download: aliyun/tsinghua/ustc/none (default: auto-detect)

.PARAMETER Model
    Whisper model size: tiny, base, small, medium, large (default: small)

.PARAMETER Language
    Language code: zh, en, ja, ko... (default: zh)

.PARAMETER FrameInterval
    Frame extraction interval in seconds (default: 30)
    Use 5 for dense extraction, or 0 for smart scene detection

.PARAMETER FrameMode
    Frame extraction mode: interval/scene (default: interval)

.PARAMETER PythonPath
    Specify Python path (optional, for virtual environments)

.EXAMPLE
    .\process_video.ps1 -Video "video.mp4"

.EXAMPLE
    # Dense frames (5 seconds)
    .\process_video.ps1 -Video "video.mp4" -FrameInterval 5

    # Smart scene detection
    .\process_video.ps1 -Video "video.mp4" -FrameInterval 0 -FrameMode scene

    # Use Chinese mirror
    .\process_video.ps1 -Video "video.mp4" -Mirror tsinghua

    # Custom proxy
    .\process_video.ps1 -Video "video.mp4" -Proxy "http://127.0.0.1:6666"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true, Position=0)]
    [string]$Video,

    [string]$Output,

    [string]$Proxy,

    [ValidateSet("aliyun", "tsinghua", "ustc", "none", "auto")]
    [string]$Mirror = "auto",

    [ValidateSet("tiny", "base", "small", "medium", "large")]
    [string]$Model = "small",

    [string]$Language = "zh",

    [int]$FrameInterval = 30,

    [ValidateSet("interval", "scene")]
    [string]$FrameMode = "interval",

    [string]$PythonPath
)

# ========== Helper Functions ==========

function Find-Command {
    param([string]$Name)
    $cmd = Get-Command $Name -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    return $null
}

function Find-Python {
    param([string]$SpecifiedPath)

    if ($SpecifiedPath) {
        if (Test-Path $SpecifiedPath) {
            Write-Host "  [INFO] Using specified Python: $SpecifiedPath" -ForegroundColor Gray
            return $SpecifiedPath
        } else {
            Write-Host "  [WARN] Specified Python not found: $SpecifiedPath" -ForegroundColor Yellow
        }
    }

    $venvPaths = @(
        "$env:USERPROFILE\whisper_env\Scripts\python.exe",
        "$env:USERPROFILE\.venv\Scripts\python.exe",
        "C:\Dev\Python\python.exe",
        "C:\Python\python.exe",
        "$env:LOCALAPPDATA\Programs\Python\Python312\python.exe",
        "$env:LOCALAPPDATA\Programs\Python\Python311\python.exe"
    )

    foreach ($p in $venvPaths) {
        if (Test-Path $p) {
            Write-Host "  [INFO] Found Python: $p" -ForegroundColor Gray
            return $p
        }
    }

    $python = Find-Command "python"
    if ($python) { return $python }

    $python3 = Find-Command "python3"
    if ($python3) { return $python3 }

    return $null
}

function Find-FFmpeg {
    $ffmpeg = Find-Command "ffmpeg"
    if ($ffmpeg) { return $ffmpeg }

    $wingetPath = Join-Path $env:LOCALAPPDATA "Microsoft\WinGet\Packages"
    if (Test-Path $wingetPath) {
        $ffmpegDir = Get-ChildItem $wingetPath -Filter "*ffmpeg*" -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($ffmpegDir) {
            $ffmpegExe = Join-Path $ffmpegDir.FullName "ffmpeg-*_build\bin\ffmpeg.exe"
            $found = Get-ChildItem (Split-Path $ffmpegExe -Parent) -Filter "ffmpeg.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($found) { return $found.FullName }
        }
    }

    return $null
}

function Test-WhisperInstalled {
    param([string]$Python)
    $result = & $Python -c "import whisper; print('ok')" 2>&1
    return ($result -eq "ok")
}

function Install-Whisper {
    param(
        [string]$Python,
        [string]$Proxy,
        [string]$Mirror
    )

    Write-Host "  Installing Whisper..." -ForegroundColor Cyan

    # Determine mirror settings
    $env:HUGGINGFACE_HUB_CACHE = "$env:USERPROFILE\.cache\huggingface"

    # pip 国内镜像源列表 (按推荐顺序)
    $pipMirrors = @{
        "tsinghua" = "https://pypi.tuna.tsinghua.edu.cn/simple"
        "aliyun"   = "https://mirrors.aliyun.com/pypi/simple"
        "ustc"     = "https://mirrors.ustc.edu.cn/pypi/web/simple"
        "douban"   = "https://pypi.doubanio.com/simple"
    }

    $pipMirrorUrl = $null
    $hfEndpoint = $null

    # Set up mirror if specified
    if ($Mirror -ne "none" -and -not $Proxy) {
        switch ($Mirror) {
            { $_ -in @("aliyun", "tsinghua", "ustc") } {
                $pipMirrorUrl = $pipMirrors[$_]
                $hfEndpoint = "https://hf-mirror.com"
                Write-Host "  Using $Mirror mirror for pip..." -ForegroundColor Gray
            }
            "auto" {
                # Auto-detect: try to find fastest mirror
                Write-Host "  Detecting fastest mirror..." -ForegroundColor Gray
                foreach ($kv in $pipMirrors.GetEnumerator()) {
                    try {
                        $test = Invoke-WebRequest -Uri "$($kv.Value)/whisper/" -TimeoutSec 5 -UseBasicParsing -ErrorAction SilentlyContinue
                        if ($test.StatusCode -eq 200 -or $test.StatusCode -eq 404) {
                            $pipMirrorUrl = $kv.Value
                            $hfEndpoint = "https://hf-mirror.com"
                            Write-Host "  Auto-selected: $($kv.Key) mirror" -ForegroundColor Green
                            break
                        }
                    } catch {
                        # Try next mirror
                    }
                }
                if (-not $pipMirrorUrl) {
                    Write-Host "  No mirror reachable, using default" -ForegroundColor Gray
                }
            }
        }
    }

    # Set HF_ENDPOINT for HuggingFace model download
    if ($hfEndpoint) {
        $env:HF_ENDPOINT = $hfEndpoint
        Write-Host "  HF_ENDPOINT: $hfEndpoint" -ForegroundColor Gray
    }

    # Build pip arguments
    $pipArgs = @("-m", "pip", "install", "openai-whisper", "--upgrade", "--trusted-host", "pypi.org", "--trusted-host", "pypi.python.org", "--trusted-host", "files.pythonhosted.org")

    # Add mirror if specified
    if ($pipMirrorUrl) {
        $pipArgs += "-i", $pipMirrorUrl
        Write-Host "  pip index: $pipMirrorUrl" -ForegroundColor Gray
    }

    # Add proxy if specified
    if ($Proxy) {
        $pipArgs += "--proxy", $Proxy
        Write-Host "  Using proxy: $Proxy" -ForegroundColor Gray
    }

    # Execute pip install
    Write-Host "  Running: $Python $($pipArgs -join ' ')" -ForegroundColor Gray
    & $Python @pipArgs

    if ($LASTEXITCODE -ne 0) {
        Write-Host "  [ERROR] Whisper installation failed" -ForegroundColor Red
        Write-Host "  Try one of these commands:" -ForegroundColor Yellow
        Write-Host "    $Python -m pip install openai-whisper -i https://pypi.tuna.tsinghua.edu.cn/simple" -ForegroundColor Yellow
        Write-Host "    $Python -m pip install openai-whisper --proxy http://your-proxy:port" -ForegroundColor Yellow
        return $false
    }

    Write-Host "  [OK] Whisper installed successfully" -ForegroundColor Green
    return $true
}

function Get-FramesByScene {
    param(
        [string]$FFmpeg,
        [string]$Video,
        [string]$OutputDir,
        [int]$MaxFrames = 100
    )

    Write-Host "  Extracting scene changes (max $MaxFrames frames)..." -ForegroundColor Gray

    # Extract I-frames (key frames) which are scene changes
    & $FFmpeg -y -loglevel error -i $Video -vf "select='eq(pict_type,I)',showinfo" -vsync vfr -frames:v $MaxFrames "$OutputDir\frame_%04d.png" 2>$null | Out-Null

    $extracted = (Get-ChildItem "$OutputDir\frame_*.png").Count
    return $extracted
}

# ========== Main ==========

Write-Host ""
Write-Host "========================================" -ForegroundColor Magenta
Write-Host "       Video Learner v2.1" -ForegroundColor Magenta
Write-Host "========================================" -ForegroundColor Magenta
Write-Host ""

# Detect tools
$ffmpeg = Find-FFmpeg
$python = Find-Python -SpecifiedPath $PythonPath

Write-Host "========== Environment Check ==========" -ForegroundColor Cyan
Write-Host "ffmpeg:  $(if($ffmpeg){$ffmpeg}else{'NOT FOUND'})"
Write-Host "python:  $(if($python){$python}else{'NOT FOUND'})"
Write-Host "Mirror:  $Mirror"
if ($Proxy) { Write-Host "Proxy:   $Proxy" }
Write-Host ""

if (-not $ffmpeg) {
    Write-Host "[ERROR] ffmpeg not found. Please install:" -ForegroundColor Red
    Write-Host "  winget install Gyan.FFmpeg" -ForegroundColor Yellow
    exit 1
}

if (-not $python) {
    Write-Host "[ERROR] Python not found. Please install:" -ForegroundColor Red
    exit 1
}

# Check Whisper
if (-not (Test-WhisperInstalled -Python $python)) {
    Write-Host "[WARN] Whisper not installed" -ForegroundColor Yellow
    $install = Read-Host "Install automatically? (Y/N)"
    if ($install -eq "Y" -or $install -eq "y") {
        if (-not (Install-Whisper -Python $python -Proxy $Proxy -Mirror $Mirror)) {
            exit 1
        }
    } else {
        Write-Host "Please run: $python -m pip install openai-whisper" -ForegroundColor Yellow
        exit 1
    }
} else {
    Write-Host "[OK] Whisper installed" -ForegroundColor Green
}

$ffprobe = $ffmpeg -replace "ffmpeg", "ffprobe"

# ========== Path Processing ==========

$Video = (Resolve-Path $Video -ErrorAction Stop).Path
$videoName = [System.IO.Path]::GetFileNameWithoutExtension($Video)
$videoDir = Split-Path $Video -Parent

if (-not $Output) {
    $Output = Join-Path $videoDir "${videoName}_video_learn"
}

$framesDir = Join-Path $Output "frames"
$audioFile = Join-Path $Output "audio.wav"
$infoFile = Join-Path $Output "video_info.json"
$transcriptFile = Join-Path $Output "transcript.txt"

# Create directories
New-Item -ItemType Directory -Force -Path $framesDir | Out-Null
New-Item -ItemType Directory -Force -Path $Output | Out-Null

Write-Host ""
Write-Host "Output directory: $Output" -ForegroundColor Green

# ========== Get Video Info ==========

Write-Host "`n[STEP 1/4] Getting video info..." -ForegroundColor Cyan

try {
    $probeOutput = & $ffprobe -v quiet -print_format json -show_format -show_streams $Video 2>&1
    if ($LASTEXITCODE -ne 0) { throw "ffprobe failed" }

    $videoInfo = $probeOutput | ConvertFrom-Json
    $duration = [double]$videoInfo.format.duration
    $width = $videoInfo.streams | Where-Object { $_.codec_type -eq "video" } | Select-Object -First 1 -ExpandProperty width
    $height = $videoInfo.streams | Where-Object { $_.codec_type -eq "video" } | Select-Object -First 1 -ExpandProperty height
    $codec = $videoInfo.streams | Where-Object { $_.codec_type -eq "video" } | Select-Object -First 1 -ExpandProperty codec_name

    $durationMin = [int]($duration / 60)
    $durationSec = [int]($duration % 60)

    Write-Host "  Duration: $durationMin min $durationSec sec"
    Write-Host "  Resolution: ${width}x${height}"
    Write-Host "  Codec: $codec"

    # Save video info
    $infoJson = @{
        duration = $duration
        width = $width
        height = $height
        codec = $codec
        model = $Model
        language = $Language
        frameInterval = $FrameInterval
        frameMode = $FrameMode
    } | ConvertTo-Json -Depth 2
    Set-Content -Path $infoFile -Value $infoJson -Encoding UTF8

} catch {
    Write-Host "[ERROR] Failed to get video info: $_" -ForegroundColor Red
    exit 1
}

# ========== Extract Frames ==========

Write-Host "`n[STEP 2/4] Extracting frames..." -ForegroundColor Cyan

$frameCount = 0

if ($FrameMode -eq "scene" -or $FrameInterval -eq 0) {
    # Smart scene detection mode
    Write-Host "  Mode: Scene detection (I-frames)" -ForegroundColor Gray
    $frameCount = Get-FramesByScene -FFmpeg $ffmpeg -Video $Video -OutputDir $framesDir -MaxFrames 100
} else {
    # Fixed interval mode
    Write-Host "  Mode: Fixed interval (every ${FrameInterval}s)" -ForegroundColor Gray

    # Clean up old frames first
    if (Test-Path $framesDir) {
        Remove-Item "$framesDir\*" -Force -ErrorAction SilentlyContinue
        Write-Host "  Cleaned up old frames" -ForegroundColor Gray
    }

    $timePoints = @()
    for ($t = 0; $t -lt $duration; $t += $FrameInterval) {
        $timePoints += $t
    }
    # Always add last frame at 95%
    $lastPoint = [int]($duration * 0.95)
    if ($lastPoint -notin $timePoints) {
        $timePoints += $lastPoint
    }

    # Sort time points numerically (fixes order issue)
    $timePoints = @($timePoints | Sort-Object -Unique)

    $frameCount = 0
    foreach ($t in $timePoints) {
        $frameCount++
        # Fix: properly convert seconds to minutes
        $mins = [Math]::Floor($t / 60)
        $secs = $t % 60
        # Format time as mm:ss (simple string concat)
        $minsStr = if ($mins -lt 10) { "0$mins" } else { "$mins" }
        $secsStr = if ($secs -lt 10) { "0$secs" } else { "$secs" }
        $timeStr = "${minsStr}m${secsStr}s"
        $frameFile = Join-Path $framesDir "frame_${timeStr}.png"

        & $ffmpeg -y -loglevel error -ss $t -i $Video -vframes 1 -q:v 2 $frameFile 2>$null | Out-Null
        if ($?) {
            Write-Host "  [$frameCount] $timeStr" -ForegroundColor Green
        } else {
            Write-Host "  [$frameCount] $timeStr FAILED" -ForegroundColor Red
        }
    }
}

Write-Host "  Total: $frameCount frames extracted" -ForegroundColor Green

# ========== Extract Audio ==========

Write-Host "`n[STEP 3/4] Extracting audio..." -ForegroundColor Cyan

& $ffmpeg -y -loglevel error -i $Video -vn -acodec pcm_s16le -ar 16000 -ac 1 $audioFile 2>$null | Out-Null
if ($?) {
    $audioSize = (Get-Item $audioFile).Length / 1MB
    Write-Host "  Done ($([math]::Round($audioSize, 1)) MB)" -ForegroundColor Green
} else {
    Write-Host "[ERROR] Audio extraction failed" -ForegroundColor Red
    exit 1
}

# ========== Transcribe ==========

Write-Host "`n[STEP 4/4] Transcribing audio..." -ForegroundColor Cyan
Write-Host "  Model: $Model, Language: $Language"

$scriptDir = Split-Path $MyInvocation.MyCommand.Path -Parent
$transcribeScript = Join-Path $scriptDir "transcribe.py"

if (-not (Test-Path $transcribeScript)) {
    Write-Host "[ERROR] transcribe.py not found: $transcribeScript" -ForegroundColor Red
    exit 1
}

# Set environment
$env:PYTHONIOENCODING = "utf-8"

# Set proxy if specified
if ($Proxy) {
    $env:HTTP_PROXY = $Proxy
    $env:HTTPS_PROXY = $Proxy
}

# Set mirror if specified (for model download)
if ($Mirror -ne "none" -and -not $Proxy) {
    $env:HF_ENDPOINT = "https://hf-mirror.com"
}

Write-Host "  Transcribing, please wait..." -ForegroundColor Yellow

& $python $transcribeScript $audioFile $transcriptFile $Model $Language 2>&1

if ($LASTEXITCODE -eq 0) {
    Write-Host "  Done!" -ForegroundColor Green
} else {
    Write-Host "[ERROR] Transcription failed" -ForegroundColor Red
    exit 1
}

# ========== Complete ==========

Write-Host ""
Write-Host "========================================" -ForegroundColor Magenta
Write-Host "[SUCCESS] All done!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Magenta
Write-Host ""
Write-Host "Output files:" -ForegroundColor Cyan
Write-Host "  Frames: $framesDir ($frameCount frames)"
Write-Host "  Audio:  $audioFile"
Write-Host "  Trans:  $transcriptFile"
Write-Host "  Info:   $infoFile"
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "  1. Use AI to analyze frames in frames/"
Write-Host "  2. Combine with transcript.txt to create notes"
Write-Host ""
