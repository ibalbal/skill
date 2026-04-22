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

## 快速开始

```powershell
# 处理视频（默认30秒一帧）
.\process_video.ps1 -Video "C:\path\to\video.mp4"

# 密集提取（每5秒一帧）
.\process_video.ps1 -Video "video.mp4" -FrameInterval 5

# 智能场景检测（自动提取关键帧）
.\process_video.ps1 -Video "video.mp4" -FrameMode scene

# 使用中国镜像下载模型
.\process_video.ps1 -Video "video.mp4" -Mirror tsinghua

# 使用代理
.\process_video.ps1 -Video "video.mp4" -Proxy "http://127.0.0.1:6666"
```

## 参数说明

| 参数 | 说明 | 默认值 |
|------|------|--------|
| `-Video` | 视频文件路径 | 必填 |
| `-Output` | 输出目录 | 视频同目录下的 `_video_learn` |
| `-FrameInterval` | 帧提取间隔（秒），0表示智能检测 | 30 |
| `-FrameMode` | 提取模式：interval(固定间隔) / scene(场景检测) | interval |
| `-Mirror` | 模型下载镜像：aliyun/tsinghua/ustc/auto/none | auto |
| `-Proxy` | 代理地址 | 无 |
| `-Model` | Whisper 模型 (tiny/base/small/medium/large) | small |
| `-Language` | 语言代码 (zh/en/ja...) | zh |
| `-PythonPath` | 指定 Python 路径（用于虚拟环境） | 自动检测 |

---

## 功能

1. **智能分帧** - 支持固定间隔(5s/10s/30s)或场景检测模式
2. **中国镜像** - 自动使用 hf-mirror.com 下载模型，解决国内网络问题
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

## 网络问题解决

### 问题：模型下载失败

Whisper 模型托管在 HuggingFace，国内访问可能较慢或失败。

### 解决方案 1：使用中国镜像（推荐）

```powershell
# 自动选择最快镜像
.\process_video.ps1 -Video "video.mp4" -Mirror auto

# 指定镜像
.\process_video.ps1 -Video "video.mp4" -Mirror tsinghua  # 清华大学
.\process_video.ps1 -Video "video.mp4" -Mirror aliyun     # 阿里云
.\process_video.ps1 -Video "video.mp4" -Mirror ustc       # 中科大
```

### 解决方案 2：使用代理

```powershell
# 使用本地代理
.\process_video.ps1 -Video "video.mp4" -Proxy "http://127.0.0.1:6666"

# 代理+镜像组合
.\process_video.ps1 -Video "video.mp4" -Proxy "http://127.0.0.1:6666" -Mirror none
```

### 解决方案 3：手动下载模型

```powershell
# 模型下载地址
# https://huggingface.co/ggerganov/whisper/tree/main

# 设置缓存目录
$env:HUGGINGFACE_HUB_CACHE = "$env:USERPROFILE\.cache\huggingface"
```

---

## 依赖安装

### 自动安装

首次运行脚本会自动检查并提示安装缺失的依赖。

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

# 使用镜像安装
pip install openai-whisper -i https://pypi.tuna.tsinghua.edu.cn/simple

# 使用代理安装
pip install openai-whisper --proxy http://127.0.0.1:6666
```

#### 3. 虚拟环境（推荐）

```powershell
# 创建虚拟环境
python -m venv whisper_env

# 激活并安装
.\whisper_env\Scripts\Activate
pip install openai-whisper
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

# 重新安装
pip uninstall openai-whisper -y
pip install openai-whisper
```

### 模型下载失败

1. 尝试使用镜像：` -Mirror tsinghua`
2. 使用代理：` -Proxy "http://127.0.0.1:6666"`
3. 手动下载模型后放到缓存目录

### Windows 安全策略拦截

```powershell
# 使用虚拟环境
python -m venv whisper_env
.\whisper_env\Scripts\Activate
pip install openai-whisper
```

---

## 注意事项

1. **分帧密度**：5秒一帧适合<30分钟视频；30秒一帧适合长视频
2. **内存占用**：Whisper 大模型需要较多内存，建议 CPU 使用 small 模型
3. **网络问题**：国内用户建议使用 `-Mirror auto` 或 `-Mirror tsinghua`
4. **虚拟环境**：推荐使用虚拟环境避免依赖冲突
