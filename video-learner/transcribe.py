#!/usr/bin/env python3
"""
音频转录脚本 - 使用 OpenAI Whisper 转录音频文件

用法:
    python transcribe.py <audio_file> <output_file> [model] [language]

参数:
    audio_file  - 音频文件路径
    output_file - 输出文本文件路径
    model       - Whisper 模型 (tiny/base/small/medium/large)，默认 small
    language    - 语言代码 (zh/en/ja/ko...)，默认 zh

示例:
    python transcribe.py audio.wav transcript.txt
    python transcribe.py audio.wav transcript.txt medium zh
    python transcribe.py audio.wav transcript.txt small en
"""

import sys
import os
import whisper

def get_model_dir():
    """获取模型缓存目录"""
    # 优先使用用户目录下的 .openclaw/whisper-models
    model_dir = os.path.join(os.path.expanduser('~'), '.openclaw', 'whisper-models')
    
    # 如果目录不存在，尝试创建
    try:
        os.makedirs(model_dir, exist_ok=True)
    except:
        # 如果创建失败，使用默认缓存目录
        model_dir = None
    
    return model_dir

def transcribe(audio_path, output_path, model_size='small', language='zh'):
    """
    转录音频文件
    
    Args:
        audio_path: 音频文件路径
        output_path: 输出文件路径
        model_size: Whisper 模型大小
        language: 语言代码
    """
    # 确保输出目录存在
    output_dir = os.path.dirname(output_path)
    if output_dir:
        os.makedirs(output_dir, exist_ok=True)
    
    # 获取模型目录
    model_dir = get_model_dir()
    
    # 加载模型
    print(f"Loading {model_size} model...", flush=True)
    if model_dir:
        print(f"Model cache: {model_dir}", flush=True)
        model = whisper.load_model(model_size, download_root=model_dir)
    else:
        model = whisper.load_model(model_size)
    
    # 转录音频
    print(f"Transcribing {audio_path}...", flush=True)
    print(f"Language: {language}", flush=True)
    
    result = model.transcribe(
        audio_path,
        language=language,
        verbose=False,
        task='transcribe'
    )
    
    # 写入结果
    with open(output_path, 'w', encoding='utf-8') as f:
        # 写入分段结果（带时间戳）
        f.write("=== Segments ===\n\n")
        for seg in result['segments']:
            start = seg['start']
            end = seg['end']
            text = seg['text'].strip()
            f.write(f'[{format_time(start)} --> {format_time(end)}] {text}\n')
        
        # 写入完整文本
        f.write(f'\n=== Full Text ===\n\n{result["text"]}')
    
    print(f"\nSaved to {output_path}", flush=True)
    
    # 输出摘要
    print(f"\n=== Summary ===", flush=True)
    print(f"Duration: {result['segments'][-1]['end']:.1f}s", flush=True)
    print(f"Segments: {len(result['segments'])}", flush=True)
    print(f"Characters: {len(result['text'])}", flush=True)

def format_time(seconds):
    """格式化时间为 mm:ss 格式"""
    mins = int(seconds // 60)
    secs = int(seconds % 60)
    return f'{mins:02d}:{secs:02d}'

def main():
    # 检查参数
    if len(sys.argv) < 3:
        print(__doc__)
        print("\n错误: 缺少必要参数")
        sys.exit(1)
    
    audio_path = sys.argv[1]
    output_path = sys.argv[2]
    model_size = sys.argv[3] if len(sys.argv) > 3 else 'small'
    language = sys.argv[4] if len(sys.argv) > 4 else 'zh'
    
    # 验证文件存在
    if not os.path.exists(audio_path):
        print(f"错误: 音频文件不存在: {audio_path}")
        sys.exit(1)
    
    # 验证模型大小
    valid_models = ['tiny', 'base', 'small', 'medium', 'large']
    if model_size not in valid_models:
        print(f"错误: 无效的模型 '{model_size}'")
        print(f"有效模型: {', '.join(valid_models)}")
        sys.exit(1)
    
    try:
        transcribe(audio_path, output_path, model_size, language)
    except Exception as e:
        print(f"错误: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)

if __name__ == '__main__':
    main()
