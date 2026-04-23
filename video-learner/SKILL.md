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
      python_modules:
        - openai-whisper
---

# Video Learner - 视频学习技能 🎬

从视频中提取画面和音频，生成完整的学习笔记。

## ⚡ 快速开始（国内用户必看）

```powershell
# 国内用户：直接使用清华镜像（推荐）
.\process_video.ps1 -Video "video.mp4" -Mirror tsinghua

# 或使用阿里云镜像
.\process_video.ps1 -Video "video.mp4" -Mirror aliyun

# 自动选择最快镜像
.\process_video.ps1 -Video "video.mp4" -Mirror auto
```

> 🇨🇳 **国内用户**：由于 HuggingFace 和 PyPI 在国内访问不稳定，请**务必指定 `-Mirror` 参数**，否则安装依赖可能失败！

## 基本用法

```powershell
# 处理视频（默认30秒一帧）
.\process_video.ps1 -Video "C:\path\to\video.mp4"

# 密集提取（每5秒一帧）
.\process_video.ps1 -Video "video.mp4" -FrameInterval 5

# 智能场景检测（自动提取关键帧）
.\process_video.ps1 -Video "video.mp4" -FrameMode scene

# 使用代理
.\process_video.ps1 -Video "video.mp4" -Proxy "http://127.0.0.1:7890"
```

## 参数说明

| 参数 | 说明 | 默认值 |
|------|------|--------|
| `-Video` | 视频文件路径 | 必填 |
| `-Output` | 输出目录 | 视频同目录下的 `_video_learn` |
| `-FrameInterval` | 帧提取间隔（秒），0表示智能检测 | 30 |
| `-FrameMode` | 提取模式：interval(固定间隔) / scene(场景检测) | interval |
| `-Mirror` | pip镜像：tsinghua/aliyun/ustc/auto/none | auto |
| `-Proxy` | 代理地址 | 无 |
| `-Model` | Whisper 模型 (tiny/base/small/medium/large) | small |
| `-Language` | 语言代码 (zh/en/ja...) | zh |
| `-PythonPath` | 指定 Python 路径（用于虚拟环境） | 自动检测 |

---

## 🇨🇳 国内镜像配置

### 问题：依赖下载失败

Whisper 依赖 PyPI 和 HuggingFace，国内访问可能超时或失败。

### ✅ 解决方案：使用国内镜像

```powershell
# 方案1：指定镜像（推荐）
.\process_video.ps1 -Video "video.mp4" -Mirror tsinghua

# 方案2：使用代理
.\process_video.ps1 -Video "video.mp4" -Proxy "http://127.0.0.1:7890"

# 方案3：手动安装依赖
pip install openai-whisper -i https://pypi.tuna.tsinghua.edu.cn/simple
$env:HF_ENDPOINT = "https://hf-mirror.com"
.\process_video.ps1 -Video "video.mp4"
```

### 可用镜像源

| 镜像 | pip 地址 | HuggingFace |
|------|---------|-------------|
| `-Mirror tsinghua` | pypi.tuna.tsinghua.edu.cn | hf-mirror.com |
| `-Mirror aliyun` | mirrors.aliyun.com/pypi | hf-mirror.com |
| `-Mirror ustc` | mirrors.ustc.edu.cn/pypi | hf-mirror.com |
| `-Mirror auto` | 自动检测最快 | hf-mirror.com |

---

## 功能

1. **智能分帧** - 支持固定间隔(5s/10s/30s)或场景检测模式
2. **国内镜像** - 自动使用清华/阿里云镜像下载模型和依赖
3. **环境自动检测** - 检测 ffmpeg、Python、Whisper，支持虚拟环境
4. **视频帧提取** - 使用 ffmpeg 提取关键帧画面
5. **音频提取** - 使用 ffmpeg 提取音频轨道
6. **语音转录** - 使用 OpenAI Whisper 转录语音为文字

---

## 分帧模式

### 固定间隔模式 (默认)

```powershell
# 每5秒一帧（密集，适合短视频）
.\process_video.ps1 -Video "video.mp4" -FrameInterval 5

# 每10秒一帧
.\process_video.ps1 -Video "video.mp4" -FrameInterval 10

# 每30秒一帧
.\process_video.ps1 -Video "video.mp4" -FrameInterval 30
```

### 智能场景检测模式

自动提取视频中的场景变化帧（I帧），适合：
- 课程视频（每章节一帧）
- 会议录屏（每个主题一帧）
- 电影/视频（每个场景一帧）

```powershell
.\process_video.ps1 -Video "video.mp4" -FrameMode scene
```

---

## 依赖安装

### 自动安装

首次运行脚本会自动检查并提示安装缺失的依赖。**国内用户请加 `-Mirror tsinghua` 参数！**

```powershell
# 国内用户（推荐）
.\process_video.ps1 -Video "video.mp4" -Mirror tsinghua

# 自动检测镜像
.\process_video.ps1 -Video "video.mp4" -Mirror auto
```

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

#### 2. Python + Whisper（国内用户）

```powershell
# 使用清华镜像安装
pip install openai-whisper -i https://pypi.tuna.tsinghua.edu.cn/simple

# 或使用阿里云镜像
pip install openai-whisper -i https://mirrors.aliyun.com/pypi/simple

# 设置 HuggingFace 镜像（模型下载）
$env:HF_ENDPOINT = "https://hf-mirror.com"
```

#### 3. 虚拟环境（推荐）

```powershell
# 创建虚拟环境
python -m venv whisper_env

# 激活并安装（使用镜像）
.\whisper_env\Scripts\Activate
pip install openai-whisper -i https://pypi.tuna.tsinghua.edu.cn/simple
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
- 短视频（<10分钟）：用 `medium` 或 `small`
- 中视频（10-30分钟）：用 `small`
- 长视频（>30分钟）：用 `small`

---

## 输出结构

```
video_learn/
├── frames/                    # 视频帧
│   ├── frame_00m00s.png
│   ├── frame_00m05s.png
│   └── ...
├── audio.wav                  # 提取的音频
├── video_info.json            # 视频信息
└── transcript.txt             # 转录结果
```

---

## 故障排除

### pip 安装超时

```powershell
# 使用镜像
pip install openai-whisper -i https://pypi.tuna.tsinghua.edu.cn/simple --trusted-host pypi.tuna.tsinghua.edu.cn

# 或使用代理
pip install openai-whisper --proxy http://127.0.0.1:7890
```

### 模型下载失败

```powershell
# 设置 HuggingFace 镜像
$env:HF_ENDPOINT = "https://hf-mirror.com"

# 或手动下载模型放到缓存目录
# 模型下载地址：https://hf-mirror.com/ggerganov/whisper
# 缓存目录：%USERPROFILE%\.cache\huggingface\hub\
```

### ffmpeg 未找到

```powershell
# 检查 ffmpeg
ffmpeg -version

# 手动添加到 PATH
$env:PATH += ";C:\path\to\ffmpeg\bin"
```

### Whisper 导入失败

```powershell
# 检查
python -c "import whisper"

# 重新安装（使用镜像）
pip uninstall openai-whisper -y
pip install openai-whisper -i https://pypi.tuna.tsinghua.edu.cn/simple
```

---

## 注意事项

1. **分帧密度**：5秒一帧适合<30分钟视频；30秒一帧适合长视频
2. **内存占用**：Whisper 大模型需要较多内存，建议 CPU 使用 small 模型
3. **网络问题**：国内用户**强烈建议**使用 `-Mirror tsinghua` 或 `-Mirror aliyun`
4. **虚拟环境**：推荐使用虚拟环境避免依赖冲突

---

*更新: 2026-04-23 - 添加国内镜像源支持*
