---
name: video-learner
description: 视频学习技能。从视频中提取帧画面和音频，通过视觉模型分析画面内容，通过 whisper 转录语音，结合两者生成完整的视频学习笔记。适用于教学视频、课程视频的内容提取和学习。
user-invocable: true
metadata:
  openclaw:
    emoji: 🎬
    requires:
      bins:
        - ffmpeg
---

# Video Learner - 视频学习技能

从视频中提取画面和音频，生成完整的学习笔记。

## 快速开始

```powershell
# 处理视频（自动检测环境）
.\process_video.ps1 -Video "C:\path\to\video.mp4"

# 使用代理下载模型
.\process_video.ps1 -Video "video.mp4" -Proxy "http://127.0.0.1:6666"

# 指定输出目录
.\process_video.ps1 -Video "video.mp4" -Output "C:\output"

# 指定 whisper 模型大小
.\process_video.ps1 -Video "video.mp4" -Model medium
```

## 参数说明

| 参数 | 说明 | 默认值 |
|------|------|--------|
| `-Video` | 视频文件路径 | 必填 |
| `-Output` | 输出目录 | 视频同目录下的 `_output` 文件夹 |
| `-Proxy` | 代理地址 | 无 |
| `-Model` | Whisper 模型 (tiny/base/small/medium/large) | small |
| `-Language` | 语言代码 (zh/en/ja...) | zh |
| `-FrameInterval` | 提取帧间隔（秒） | 30 |

---

## 功能

1. **视频帧提取** - 使用 ffmpeg 提取关键帧画面
2. **音频提取** - 使用 ffmpeg 提取音频轨道
3. **语音转录** - 使用 OpenAI Whisper 转录语音为文字
4. **画面分析** - 使用视觉模型分析视频帧内容
5. **内容整合** - 结合画面和音频生成完整学习笔记

---

## 依赖检测与安装

### 自动检测

脚本会自动检测以下工具：
- ffmpeg / ffprobe
- Python / pip
- whisper

### 手动安装

#### 1. ffmpeg

```powershell
# Windows - 使用 winget
winget install Gyan.FFmpeg

# macOS - 使用 brew
brew install ffmpeg

# Linux - 使用 apt
sudo apt install ffmpeg
```

#### 2. Python + Whisper

```powershell
# 安装 whisper
pip install openai-whisper

# 使用代理安装
pip install openai-whisper --proxy http://127.0.0.1:6666
```

---

## 工作流程

### 步骤 1：获取视频信息

```powershell
# 使用 ffprobe 获取视频信息（JSON 格式）
ffprobe -v quiet -print_format json -show_format -show_streams "video.mp4"
```

关键信息：
- `format.duration` - 视频时长（秒）
- `stream.width` / `stream.height` - 分辨率
- `stream.codec_name` - 编码格式

### 步骤 2：提取视频帧

```powershell
# 方式 A：按时间间隔提取（每 30 秒一帧）
ffmpeg -i "video.mp4" -vf "fps=1/30" "frames/frame_%04d.png"

# 方式 B：按百分比提取（10%, 25%, 50%, 75%, 90%）
$duration = 750  # 从 ffprobe 获取
@("0.1", "0.25", "0.5", "0.75", "0.9") | ForEach-Object {
    $time = [int]($duration * [double]$_)
    ffmpeg -ss $time -i "video.mp4" -vframes 1 "frames/frame_${time}s.png"
}

# 方式 C：指定时间点
@("00:00:10", "00:01:00", "00:05:00") | ForEach-Object {
    ffmpeg -ss $_ -i "video.mp4" -vframes 1 "frames/frame_$_`_png"
}
```

### 步骤 3：提取音频

```powershell
# 提取为 WAV 格式（16kHz 单声道，适合 whisper）
ffmpeg -i "video.mp4" -vn -acodec pcm_s16le -ar 16000 -ac 1 "audio.wav"

# 或提取为 MP3 格式（文件更小）
ffmpeg -i "video.mp4" -vn -acodec libmp3lame -ar 16000 -ac 1 "audio.mp3"
```

### 步骤 4：转录音频

**Python 脚本 (`transcribe.py`)：**

```python
#!/usr/bin/env python3
import whisper
import sys
import os

def transcribe(audio_path, output_path, model_size='small', language='zh'):
    """转录音频文件"""
    # 模型缓存目录
    model_dir = os.path.join(os.path.expanduser('~'), '.openclaw', 'whisper-models')
    os.makedirs(model_dir, exist_ok=True)
    
    print(f"Loading {model_size} model...", flush=True)
    model = whisper.load_model(model_size, download_root=model_dir)
    
    print(f"Transcribing {audio_path}...", flush=True)
    result = model.transcribe(audio_path, language=language, verbose=False)
    
    # 写入结果
    with open(output_path, 'w', encoding='utf-8') as f:
        for seg in result['segments']:
            f.write(f'[{seg["start"]:.1f}s --> {seg["end"]:.1f}s] {seg["text"]}\n')
        f.write(f'\n=== Full Text ===\n{result["text"]}')
    
    print(f"Saved to {output_path}", flush=True)

if __name__ == '__main__':
    if len(sys.argv) < 3:
        print("Usage: python transcribe.py <audio> <output> [model] [language]")
        sys.exit(1)
    
    transcribe(
        audio_path=sys.argv[1],
        output_path=sys.argv[2],
        model_size=sys.argv[3] if len(sys.argv) > 3 else 'small',
        language=sys.argv[4] if len(sys.argv) > 4 else 'zh'
    )
```

**使用示例：**

```powershell
# 基本用法
python transcribe.py audio.wav transcript.txt

# 指定模型和语言
python transcribe.py audio.wav transcript.txt medium zh

# 英文视频
python transcribe.py audio.wav transcript.txt small en
```

### 步骤 5：分析视频帧

提示词模板：

```
请读取以下视频帧图片，逐帧描述画面中实际显示的内容：

[帧图片路径列表]

要求：
1. 逐帧描述画面中的文字、代码、图表、UI元素
2. 如果画面中有代码，完整抄录代码内容
3. 如果画面中有图表，描述图表的含义
4. 不要猜测或编造任何内容，只描述画面中实际显示的内容
```

### 步骤 6：整合学习笔记

提示词模板：

```
请根据以下信息生成完整的学习笔记：

## 视频帧分析
[步骤5的结果]

## 音频转录
[步骤4的结果]

要求：
1. 结合画面和讲解内容，生成结构化的学习笔记
2. 如果有代码，整理代码示例并解释
3. 提取关键知识点，用表格或列表呈现
4. 生成章节标题和小结
```

---

## Whisper 模型选择

| 模型 | 参数量 | 中文效果 | VRAM | CPU 速度 |
|------|--------|----------|------|----------|
| tiny | 39M | 较差 | ~1GB | 最快 |
| base | 74M | 一般 | ~1GB | 快 |
| **small** | 244M | 良好 | ~2GB | 中等 |
| medium | 769M | 很好 | ~5GB | 慢 |
| large | 1.5B | 最好 | ~10GB | 最慢 |

**推荐：**
- 中文视频使用 `small` 或 `medium`
- 英文视频使用 `base` 或 `small`
- 长视频（>30分钟）使用 `small`

---

## 输出结构

```
video_output/
├── frames/                    # 视频帧
│   ├── frame_00m10s.png
│   ├── frame_01m00s.png
│   └── ...
├── audio.wav                  # 提取的音频
├── transcript.txt             # 转录结果
└── notes.md                   # 整合的学习笔记（可选）
```

---

## 故障排除

### ffmpeg 未找到

```powershell
# 检查 ffmpeg 是否在 PATH 中
ffmpeg -version

# 如果未找到，添加到 PATH
$env:PATH += ";C:\path\to\ffmpeg\bin"
```

### Python 模块找不到

```powershell
# 设置 PYTHONPATH
$env:PYTHONPATH = "/path/to/python/site-packages"

# 或使用 -m 参数
python -m whisper transcribe audio.wav
```

### 代理连接失败

```powershell
# 测试代理连接
curl.exe --proxy http://127.0.0.1:6666 https://openai.com

# 设置环境变量
$env:HTTP_PROXY = "http://127.0.0.1:6666"
$env:HTTPS_PROXY = "http://127.0.0.1:6666"
```

### 转录结果乱码

```python
# 确保使用 UTF-8 编码
with open('transcript.txt', 'w', encoding='utf-8') as f:
    f.write(text)
```

### Windows 安全策略拦截

Windows 可能阻止执行 `AppData\Local` 目录下的程序，解决方案：

```powershell
# 方案 1：复制 Python 到受信目录
Copy-Item "$env:LOCALAPPDATA\Programs\Python\Python312" "C:\Dev\Python" -Recurse

# 方案 2：使用完整路径
& "C:\path\to\python.exe" script.py
```

---

## 高级用法

### 批量处理

```powershell
# 处理目录下所有视频
Get-ChildItem *.mp4 | ForEach-Object {
    .\process_video.ps1 -Video $_.FullName
}
```

### 自定义帧提取

```powershell
# 提取场景变化帧（I帧）
ffmpeg -i "video.mp4" -vf "select='eq(pict_type,I)'" -vsync vfr "frames/frame_%04d.png"

# 提取指定时间段
ffmpeg -ss 00:01:00 -to 00:02:00 -i "video.mp4" -vf "fps=1" "frames/frame_%04d.png"
```

### 分段转录（长视频）

```python
# 将长音频分割成 10 分钟片段
import subprocess

def split_audio(input_path, segment_seconds=600):
    # 获取总时长
    result = subprocess.run(
        ['ffprobe', '-v', 'error', '-show_entries', 'format=duration', 
         '-of', 'default=noprint_wrappers=1:nokey=1', input_path],
        capture_output=True, text=True
    )
    duration = float(result.stdout.strip())
    
    # 分割
    for i, start in enumerate(range(0, int(duration), segment_seconds)):
        output = f"segment_{i:03d}.wav"
        subprocess.run([
            'ffmpeg', '-y', '-i', input_path,
            '-ss', str(start), '-t', str(segment_seconds),
            '-acodec', 'pcm_s16le', '-ar', '16000', '-ac', '1', output
        ])
```

---

## 注意事项

1. **内存占用**：Whisper 大模型需要较多内存，建议 CPU 使用 small 模型
2. **视频长度**：超过 1 小时的视频建议分段处理
3. **音频质量**：背景噪音会影响转录质量，尽量提取清晰音轨
4. **代理配置**：下载模型需要访问 GitHub 和 HuggingFace，确保代理可用
5. **安全策略**：Windows 可能阻止执行用户目录下的程序，需复制到受信目录
