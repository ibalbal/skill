# Video Learner 🎬

从视频中自动提取帧画面和音频，转录语音，生成学习笔记。

## 快速开始

### 1. 安装依赖

```powershell
# 安装 ffmpeg
winget install Gyan.FFmpeg

# 安装 Whisper
pip install openai-whisper
```

### 2. 运行

```powershell
# 基本用法（默认30秒一帧）
.\process_video.ps1 -Video "C:\path\to\video.mp4"

# 密集提取（每5秒一帧）
.\process_video.ps1 -Video "video.mp4" -FrameInterval 5

# 智能场景检测
.\process_video.ps1 -Video "video.mp4" -FrameMode scene

# 使用中国镜像下载模型
.\process_video.ps1 -Video "video.mp4" -Mirror tsinghua
```

## 新功能 v2.1

### 🔥 智能分帧

| 模式 | 参数 | 适用场景 |
|------|------|----------|
| 固定间隔 | `-FrameInterval 5` | 短视频、需要细节 |
| 固定间隔 | `-FrameInterval 30` | 长视频、概览 |
| 场景检测 | `-FrameMode scene` | 课程章节、场景变化 |

### 🇨🇳 中国镜像支持

解决 HuggingFace 模型下载慢/失败的问题：

```powershell
# 自动选择最快镜像（推荐）
-Mirror auto

# 指定镜像
-Mirror tsinghua  # 清华大学
-Mirror aliyun    # 阿里云
-Mirror ustc      # 中科大
```

## 参数说明

| 参数 | 说明 | 默认值 |
|------|------|--------|
| `-Video` | 视频文件路径 | 必填 |
| `-Output` | 输出目录 | 视频同目录 `_video_learn` |
| `-FrameInterval` | 帧间隔（秒） | 30 |
| `-FrameMode` | 提取模式 | interval |
| `-Mirror` | 模型镜像 | auto |
| `-Proxy` | 代理地址 | 无 |
| `-Model` | Whisper 模型 | small |
| `-Language` | 语言 | zh |
| `-PythonPath` | Python 路径 | 自动 |

## 模型选择

| 模型 | 中文效果 | 速度 | 推荐 |
|------|----------|------|------|
| tiny | 较差 | 最快 | 预览 |
| base | 一般 | 快 | 英文 |
| **small** | 良好 | 中等 | 中文通用 |
| medium | 很好 | 慢 | 重要内容 |
| large | 最好 | 最慢 | 精确转录 |

## 输出文件

```
video_learn/
├── frames/              # 视频帧
├── audio.wav            # 音频
├── video_info.json      # 信息
└── transcript.txt       # 转录
```

## 故障排除

### 模型下载失败

```powershell
# 方案1：使用镜像
.\process_video.ps1 -Video "video.mp4" -Mirror tsinghua

# 方案2：使用代理
.\process_video.ps1 -Video "video.mp4" -Proxy "http://127.0.0.1:6666"
```

### Python 问题

```powershell
# 使用虚拟环境
.\process_video.ps1 -Video "video.mp4" -PythonPath "C:\Users\49124\whisper_env\Scripts\python.exe"
```

## 系统要求

- Windows / macOS / Linux
- Python 3.8+
- ffmpeg
- 建议 8GB+ 内存

---

详见 [SKILL.md](SKILL.md)
