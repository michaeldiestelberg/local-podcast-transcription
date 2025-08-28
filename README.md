# Podcast Transcription Tool

A powerful Python-based tool for transcribing podcast audio files into markdown format using [parakeet-mlx](https://github.com/senstella/parakeet-mlx). This tool handles everything from short clips to lengthy multi-hour episodes through intelligent audio chunking to manage memory limitations.

## Table of Contents
- [Installation](#installation)
- [Virtual Environment](#virtual-environment)
- [Usage Guide](#usage-guide)
- [Available Models](#available-models)
- [How It Works](#how-it-works)
- [Troubleshooting](#troubleshooting)

## Installation

### Step 1: Install Homebrew (if not already installed)
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

### Step 2: Install Python 3.10+ and FFmpeg
```bash
# Install the latest Python (if you don't have 3.10+ already)
brew install python

# Install FFmpeg (required for audio processing)
brew install ffmpeg

# Verify installations
python3 --version  # Should show 3.10 or higher
ffmpeg -version    # Should display ffmpeg version info
```

## Virtual Environment

### Setting Up (First Time Only)

```bash
# Navigate to the project directory
cd podcast-transcription

# Create a virtual environment
python3 -m venv venv

# Activate the virtual environment
source venv/bin/activate

# You'll see (venv) in your terminal prompt when activated

# Install required packages
pip install -r requirements.txt
```

### Daily Usage

```bash
# To activate the virtual environment (required before using the script)
source venv/bin/activate

# Your terminal prompt will show (venv) when active

# To deactivate when done
deactivate
```

**Important:** You must activate the virtual environment every time you open a new terminal session to use the transcription script.

## Usage Guide

### Basic Transcription

```bash
# Activate virtual environment first
source venv/bin/activate

# Transcribe an audio file (creates output with same name + .md)
python transcribe_podcast.py your_podcast.mp3

# Example: podcast.mp3 → podcast.md
```

### Specify Custom Output

```bash
python transcribe_podcast.py input_audio.mp3 -o custom_output.md
```

### Adjust Memory Settings

For systems with limited memory or very long files:
```bash
# Use smaller chunks (3 minutes instead of default 5)
python transcribe_podcast.py long_podcast.mp3 --chunk-duration 180
```

### Use Different Models

```bash
# Default model (English, 600M parameters)
python transcribe_podcast.py podcast.mp3

# Larger English model (1.1B parameters, better accuracy)
python transcribe_podcast.py podcast.mp3 --model mlx-community/parakeet-tdt-1.1b-v2

# Multilingual model (supports 25 languages)
python transcribe_podcast.py podcast.mp3 --model mlx-community/parakeet-tdt-0.6b-v3
```

## Available Models

### English-Only Models
- **`mlx-community/parakeet-tdt-0.6b-v2`** (Default)
  - 600M parameters
  - Good balance of speed and accuracy
  - Best for most English podcasts

- **`mlx-community/parakeet-tdt-1.1b-v2`**
  - 1.1B parameters
  - Higher accuracy but slower
  - Recommended for important transcriptions

### Multilingual Model
- **`mlx-community/parakeet-tdt-0.6b-v3`**
  - 600M parameters
  - Supports 25 languages including: English, Spanish, French, German, Italian, Portuguese, Dutch, Polish, Russian, Chinese, Japanese, Korean, Arabic, Hindi, and more
  - Based on [NVIDIA's Parakeet TDT 0.6B](https://huggingface.co/nvidia/parakeet-tdt-0.6b-v3)
  - Ideal for non-English or mixed-language content

First run with any model will download it (600MB-1.1GB depending on model size). Models are cached locally for future use.

## Output Format

The tool generates a markdown file containing:
- **Header metadata**: File name, duration, transcription date, model used
- **Processing statistics**: Total time, processing speed ratio
- **Transcript**: Clean, formatted text of the entire audio

Example output structure:
```markdown
# Transcript: My Podcast Episode

**Original File:** my_podcast.mp3
**Duration:** 1:23:45
**Transcribed:** 2024-01-15 14:30:00
**Model:** mlx-community/parakeet-tdt-0.6b-v2

---

[Full transcript text follows...]
```

## How It Works

### Technical Overview

The script implements intelligent audio processing to handle long-form content:

1. **Audio Loading**: Uses `librosa` to load audio at 16kHz mono (standard for speech recognition)

2. **Memory Management**: 
   - Attempts direct transcription for short files
   - Automatically switches to chunked processing for long files or if memory errors occur
   - Default chunk size: 5 minutes (configurable)

3. **Chunk Processing**:
   - Splits audio into manageable segments
   - Creates temporary WAV files for each chunk
   - Processes sequentially with progress tracking
   - Combines all chunks into final transcript

4. **Model Integration**:
   - Uses parakeet-mlx's `from_pretrained()` API
   - Leverages Apple Metal Performance Shaders for acceleration on Mac
   - Automatic model downloading and caching

### Key Components

- **`transcribe_audio()`**: Main orchestration function
- **`transcribe_in_chunks()`**: Handles audio splitting and chunk processing
- **Progress tracking**: Shows real-time progress with word counts per chunk
- **Error handling**: Automatic fallback to chunking on memory errors

## Troubleshooting

### Metal Memory Errors
If you see `metal::malloc` errors:
```bash
# Reduce chunk duration (e.g., 3 minutes)
python transcribe_podcast.py podcast.mp3 --chunk-duration 180
```

### Python Version Issues
If parakeet-mlx fails to install:
```bash
# Check Python version (must be 3.10+)
python3 --version

# If too old, install the latest version via Homebrew
brew install python
python3 -m venv venv
```

### Virtual Environment Not Found
```bash
# Make sure you're in the project directory
cd /path/to/podcast-transcription

# Recreate virtual environment if needed
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

### FFmpeg Not Found
```bash
brew install ffmpeg
```

## Performance Notes

- **Processing Speed**: Typically 20-30x real-time on Apple Silicon (e.g., 1-hour podcast in ~2 minutes on M4)
- **Memory Usage**: ~4-8GB for default settings
- **Model Download**: First run downloads model (600MB-1.1GB), one-time operation
- **Disk Space**: Temporary files created in `/tmp/` are automatically cleaned up

## License

MIT License - See LICENSE file for details