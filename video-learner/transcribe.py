#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Audio transcription script using OpenAI Whisper

Optimized v2.1:
- Fix model loading logic
- Support GPU auto-detection
- Support Chinese mirrors for model download
- Better error handling

Usage:
    python transcribe.py <audio_file> <output_file> [model] [language]

Example:
    python transcribe.py audio.wav transcript.txt
    python transcribe.py audio.wav transcript.txt medium zh
    python transcribe.py audio.wav transcript.txt small en
"""

import sys
import os
import warnings
import torch

# Ignore common warnings
warnings.filterwarnings('ignore', category=UserWarning)

def setup_mirror():
    """Setup Chinese mirror for model download with fallback"""
    # Check if HF_ENDPOINT is already set
    hf_endpoint = os.environ.get('HF_ENDPOINT')

    if hf_endpoint:
        print(f"Using HF endpoint: {hf_endpoint}")
        return

    # 中国镜像列表 (按推荐顺序)
    mirrors = [
        ('https://hf-mirror.com', 'HF-Mirror'),
        ('https://huggingface.co', 'HuggingFace Official'),
    ]

    # 尝试检测最快的镜像
    import urllib.request
    import socket
    socket.setdefaulttimeout(5)

    for url, name in mirrors:
        try:
            # 尝试访问镜像根目录
            req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
            response = urllib.request.urlopen(req, timeout=5)
            if response.status in [200, 301, 302, 403, 404]:
                os.environ['HF_ENDPOINT'] = url
                print(f"Using {name}: {url}")
                return
        except Exception:
            # 尝试下一个镜像
            continue

    # 默认使用 hf-mirror.com（即使检测失败也尝试使用）
    os.environ['HF_ENDPOINT'] = 'https://hf-mirror.com'
    print("Using HF-Mirror (default): https://hf-mirror.com")

def get_model_dir():
    """Get model cache directory"""
    model_dir = os.path.join(os.path.expanduser('~'), '.openclaw', 'whisper-models')

    try:
        os.makedirs(model_dir, exist_ok=True)
    except Exception as e:
        print(f"Warning: Cannot create model directory: {e}")
        model_dir = None

    return model_dir

def check_gpu():
    """Detect GPU availability"""
    if torch.cuda.is_available():
        gpu_name = torch.cuda.get_device_name(0)
        gpu_memory = torch.cuda.get_device_properties(0).total_memory / 1e9
        print(f"GPU detected: {gpu_name} ({gpu_memory:.1f} GB)")
        return True
    else:
        print("Using CPU mode")
        return False

def load_model(model_size='small'):
    """Load Whisper model"""
    import whisper

    model_dir = get_model_dir()

    print(f"Loading whisper {model_size} model...", flush=True)

    # Try to use mirror if available
    setup_mirror()

    try:
        if model_dir:
            print(f"Model cache: {model_dir}", flush=True)
            model = whisper.load_model(model_size, download_root=model_dir)
        else:
            model = whisper.load_model(model_size)
    except Exception as e:
        print(f"Failed to load with custom cache, trying default: {e}")
        model = whisper.load_model(model_size)

    # Check what device it's on
    if hasattr(model, 'device'):
        print(f"Model loaded on: {model.device}")

    return model

def transcribe(audio_path, output_path, model_size='small', language='zh'):
    """
    Transcribe audio file

    Args:
        audio_path: Audio file path
        output_path: Output file path
        model_size: Whisper model size
        language: Language code
    """
    # Check audio file
    if not os.path.exists(audio_path):
        raise FileNotFoundError(f"Audio file not found: {audio_path}")

    audio_size = os.path.getsize(audio_path) / (1024 * 1024)
    print(f"Audio file: {audio_path} ({audio_size:.1f} MB)")

    # Ensure output directory exists
    output_dir = os.path.dirname(output_path)
    if output_dir:
        os.makedirs(output_dir, exist_ok=True)

    # Detect GPU
    use_gpu = check_gpu()

    # Load model
    model = load_model(model_size)

    # Transcribe
    print(f"Transcribing...", flush=True)
    print(f"Language: {language}", flush=True)

    try:
        result = model.transcribe(
            audio_path,
            language=language,
            verbose=False,
            task='transcribe',
            fp16=use_gpu  # Only use FP16 on GPU
        )
    except Exception as e:
        raise RuntimeError(f"Transcription failed: {e}")

    # Write result
    with open(output_path, 'w', encoding='utf-8') as f:
        # Write segments with timestamps
        f.write("=== Segments ===\n\n")
        for seg in result['segments']:
            start = seg['start']
            end = seg['end']
            text = seg['text'].strip()
            f.write(f'[{format_time(start)} --> {format_time(end)}] {text}\n')

        # Write full text
        f.write(f'\n=== Full Text ===\n\n{result["text"]}')

    print(f"\nSaved to: {output_path}")

    # Summary
    if result['segments']:
        duration = result['segments'][-1]['end']
    else:
        duration = 0

    print(f"\n=== Summary ===")
    print(f"Duration: {duration:.1f}s ({duration/60:.1f} min)")
    print(f"Segments: {len(result['segments'])}")
    print(f"Characters: {len(result['text'])}")

    return result

def format_time(seconds):
    """Format time as mm:ss"""
    mins = int(seconds // 60)
    secs = int(seconds % 60)
    return f'{mins:02d}:{secs:02d}'

def main():
    # Check arguments
    if len(sys.argv) < 3:
        print(__doc__)
        print("\nError: Missing required arguments")
        sys.exit(1)

    audio_path = sys.argv[1]
    output_path = sys.argv[2]
    model_size = sys.argv[3] if len(sys.argv) > 3 else 'small'
    language = sys.argv[4] if len(sys.argv) > 4 else 'zh'

    # Validate file exists
    if not os.path.exists(audio_path):
        print(f"Error: Audio file not found: {audio_path}")
        sys.exit(1)

    # Validate model size
    valid_models = ['tiny', 'base', 'small', 'medium', 'large']
    if model_size not in valid_models:
        print(f"Error: Invalid model '{model_size}'")
        print(f"Valid models: {', '.join(valid_models)}")
        sys.exit(1)

    try:
        transcribe(audio_path, output_path, model_size, language)
    except Exception as e:
        print(f"Error: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)

if __name__ == '__main__':
    main()
