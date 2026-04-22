# Video Learner 🎬

从视频中自动提取帧画面和音频，转录语音，生成学习笔记。

## 快速开始

### 1. 安装依赖

```powershell
# 安装 ffmpeg
winget install Gyan.FFmpeg

# 安装 Python (如果没有)
# Windows: https://python.org/downloads
# macOS: brew install python3
# Linux: sudo apt install python3 python3-pip

# 安装 Whisper
pip install openai-whisper

# 如果需要代理
pip install openai-whisper --proxy http://127.0.0.1:6666
```

### 2. 运行

```powershell
# Windows PowerShell
.\process_video.ps1 -Video "C:\path\to\video.mp4"

# 使用代理下载模型
.\process_video.ps1 -Video "video.mp4" -Proxy "http://127.0.0.1:6666"

# 指定更大的模型（效果更好但更慢）
.\process_video.ps1 -Video "video.mp4" -Model medium
```

### 3. 分析结果

处理完成后，使用 AI 分析：

```
请分析以下视频帧图片和转录文本，生成学习笔记：

视频帧目录：video_output/frames/
转录文件：video_output/transcript.txt
```

## 参数说明

| 参数 | 说明 | 默认值 |
|------|------|--------|
| `-Video` | 视频文件路径 | 必填 |
| `-Output` | 输出目录 | 视频同目录下 `_output` |
| `-Proxy` | 代理地址 | 无 |
| `-Model` | Whisper 模型 | small |
| `-Language` | 语言 (zh/en/ja...) | zh |
| `-FrameInterval` | 帧提取间隔（秒） | 30 |

## 模型选择

| 模型 | 中文效果 | 速度 | 推荐场景 |
|------|----------|------|----------|
| tiny | 较差 | 最快 | 快速预览 |
| base | 一般 | 快 | 英文视频 |
| **small** | 良好 | 中等 | 中文视频 |
| medium | 很好 | 慢 | 重要内容 |
| large | 最好 | 最慢 | 精确转录 |

## 输出文件

```
video_output/
├── frames/              # 视频帧图片
│   ├── frame_00m10s.png
│   ├── frame_01m00s.png
│   └── ...
├── audio.wav            # 提取的音频
└── transcript.txt       # 转录结果（带时间戳）
```

## 故障排除

### ffmpeg 未找到

```powershell
# 检查安装
ffmpeg -version

# 手动添加到 PATH
$env:PATH += ";C:\path\to\ffmpeg\bin"
```

### Python 安全策略拦截 (Windows)

Windows 可能阻止执行 `AppData\Local` 目录下的程序：

```powershell
# 解决方案：复制 Python 到受信目录
Copy-Item "$env:LOCALAPPDATA\Programs\Python\Python312" "C:\Dev\Python" -Recurse
```

### 代理问题

```powershell
# 测试代理
curl.exe --proxy http://127.0.0.1:6666 https://github.com

# 设置环境变量
$env:HTTP_PROXY = "http://127.0.0.1:6666"
$env:HTTPS_PROXY = "http://127.0.0.1:6666"
```

## 手动步骤

如果脚本无法运行，可以手动执行：

```powershell
# 1. 提取帧（每30秒一帧）
ffmpeg -i video.mp4 -vf "fps=1/30" frames/frame_%04d.png

# 2. 提取音频
ffmpeg -i video.mp4 -vn -acodec pcm_s16le -ar 16000 -ac 1 audio.wav

# 3. 转录
python transcribe.py audio.wav transcript.txt small zh
```

## 系统要求

- **操作系统**: Windows / macOS / Linux
- **Python**: 3.8+
- **ffmpeg**: 任意版本
- **内存**: 建议 8GB+（使用 medium/large 模型）
- **磁盘**: 模型缓存约 1-2GB

## 文件说明

| 文件 | 说明 |
|------|------|
| `SKILL.md` | 完整技能文档 |
| `README.md` | 快速入门（本文件） |
| `process_video.ps1` | PowerShell 处理脚本 |
| `transcribe.py` | Python 转录脚本 |

## 更多信息

详见 [SKILL.md](SKILL.md) 获取完整文档。
