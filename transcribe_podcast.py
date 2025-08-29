#!/usr/bin/env python3
# Falls back to: ./venv/bin/python if run directly
"""
Audio transcription script using parakeet-mlx.
Optimized for long podcast files.
"""

import argparse
import os
import sys
import time
from pathlib import Path
from datetime import timedelta
import warnings
warnings.filterwarnings("ignore")

try:
    from parakeet_mlx import from_pretrained
except ImportError:
    print("Error: parakeet-mlx is not installed.")
    print("Please install it with: pip install parakeet-mlx")
    print("Also ensure ffmpeg is installed on your system.")
    sys.exit(1)

try:
    import soundfile as sf
    import librosa
    import numpy as np
except ImportError as e:
    print(f"Error: Missing required package: {e}")
    print("Please install with: pip install soundfile librosa numpy")
    sys.exit(1)


def format_time(seconds):
    """Convert seconds to human-readable format."""
    return str(timedelta(seconds=int(seconds)))


def transcribe_in_chunks(model, audio_path, chunk_duration=300, total_duration=None):
    """
    Transcribe audio in chunks to handle long files.
    
    Args:
        model: The loaded parakeet model
        audio_path: Path to the audio file
        chunk_duration: Duration of each chunk in seconds
        total_duration: Total duration of the audio file
    
    Returns:
        Combined transcript text
    """
    print(f"\nLoading audio for chunked processing...")
    
    try:
        # Load audio with librosa (handles various formats)
        audio, sr = librosa.load(str(audio_path), sr=16000, mono=True)
        
        # Calculate chunk size
        chunk_samples = int(chunk_duration * sr)
        total_samples = len(audio)
        num_chunks = (total_samples + chunk_samples - 1) // chunk_samples
        
        print(f"Splitting into {num_chunks} chunks of up to {chunk_duration/60:.1f} minutes each")
        print("Processing chunks:")
        
        transcripts = []
        
        for i in range(num_chunks):
            start_sample = i * chunk_samples
            end_sample = min((i + 1) * chunk_samples, total_samples)
            chunk_audio = audio[start_sample:end_sample]
            
            # Create temporary file for chunk
            temp_file = f"/tmp/chunk_{i}.wav"
            sf.write(temp_file, chunk_audio, sr)
            
            # Progress indicator
            chunk_start_time = start_sample / sr
            chunk_end_time = end_sample / sr
            print(f"  Chunk {i+1}/{num_chunks}: {format_time(chunk_start_time)} - {format_time(chunk_end_time)}...", end=' ', flush=True)
            
            try:
                # Transcribe chunk
                result = model.transcribe(temp_file)
                if hasattr(result, 'text'):
                    chunk_text = result.text.strip()
                    transcripts.append(chunk_text)
                    print(f"✓ ({len(chunk_text.split())} words)")
                else:
                    print("⚠ No text returned")
            except Exception as e:
                print(f"✗ Error: {e}")
            finally:
                # Clean up temp file
                import os
                if os.path.exists(temp_file):
                    os.remove(temp_file)
        
        # Combine all transcripts
        transcript = " ".join(transcripts)
        return transcript
        
    except Exception as e:
        print(f"\nError processing audio in chunks: {e}")
        return "[Transcription failed]"


def transcribe_audio(audio_path, output_path=None, model_name="mlx-community/parakeet-tdt-0.6b-v2", chunk_duration=300):
    """
    Transcribe an audio file using parakeet-mlx.
    
    Args:
        audio_path: Path to the input audio file
        output_path: Path for the output markdown file (optional)
        model_name: Model identifier to use (default: mlx-community/parakeet-tdt-0.6b-v2)
        chunk_duration: Duration of each chunk in seconds (default: 300 = 5 minutes)
    """
    audio_path = Path(audio_path)
    
    if not audio_path.exists():
        print(f"Error: Audio file '{audio_path}' not found.")
        sys.exit(1)
    
    # Determine output path
    if output_path is None:
        output_path = audio_path.with_suffix('.md')
    else:
        output_path = Path(output_path)
    
    print(f"Loading audio file: {audio_path}")
    print(f"Output will be saved to: {output_path}")
    
    # Get audio duration for progress tracking
    try:
        audio_info = sf.info(str(audio_path))
        total_duration = audio_info.duration
        sample_rate = audio_info.samplerate
        print(f"Audio duration: {format_time(total_duration)}")
        print(f"Sample rate: {sample_rate} Hz")
    except Exception as e:
        print(f"Warning: Could not determine audio info: {e}")
        total_duration = None
        sample_rate = 16000  # Default sample rate
    
    # Initialize Parakeet
    print(f"\nLoading model: {model_name}")
    print("This may take a moment on first run as the model downloads.")
    
    start_time = time.time()
    
    try:
        # Load the model
        model = from_pretrained(model_name)
    except Exception as e:
        print(f"Error loading model: {e}")
        print("Make sure ffmpeg is installed on your system.")
        sys.exit(1)
    
    print("Model loaded successfully!")
    
    # For long audio files, we'll process in chunks
    if total_duration and total_duration > chunk_duration:
        print(f"\nAudio is longer than {chunk_duration/60:.0f} minutes. Processing in chunks...")
        transcript = transcribe_in_chunks(model, audio_path, chunk_duration, total_duration)
    else:
        print("\nProcessing entire audio file...")
        try:
            result = model.transcribe(str(audio_path))
            transcript = result.text.strip() if hasattr(result, 'text') else str(result)
        except Exception as e:
            print(f"Error during transcription: {e}")
            print("File may be too large. Trying chunked processing...")
            # Fallback to chunked processing
            transcript = transcribe_in_chunks(model, audio_path, chunk_duration, total_duration or chunk_duration * 20)
    
    # Calculate processing time
    processing_time = time.time() - start_time
    print(f"\nTranscription completed in {format_time(processing_time)}")
    
    if total_duration:
        speed_ratio = total_duration / processing_time
        print(f"Processing speed: {speed_ratio:.2f}x real-time")
    
    # Create markdown output
    markdown_content = f"""# Transcript: {audio_path.name}

## Metadata
- **File**: {audio_path.name}
- **Duration**: {format_time(total_duration) if total_duration else 'Unknown'}
- **Transcription Date**: {time.strftime('%Y-%m-%d %H:%M:%S')}
- **Model**: {model_name}
- **Processing Time**: {format_time(processing_time)}

---

## Full Transcript

{transcript}

---

*Transcribed using parakeet-mlx*
"""
    
    # Save the output
    try:
        output_path.parent.mkdir(parents=True, exist_ok=True)
        output_path.write_text(markdown_content, encoding='utf-8')
        print(f"\nTranscript saved to: {output_path}")
        
        # Print summary
        word_count = len(transcript.split())
        print(f"Transcript contains approximately {word_count:,} words")
        
    except Exception as e:
        print(f"Error saving transcript: {e}")
        sys.exit(1)


def main():
    parser = argparse.ArgumentParser(
        description="Transcribe audio files (optimized for long podcasts) using parakeet-mlx"
    )
    parser.add_argument(
        "audio_file",
        help="Path to the audio file to transcribe"
    )
    parser.add_argument(
        "-o", "--output",
        help="Output markdown file path (default: same as input with .md extension)",
        default=None
    )
    parser.add_argument(
        "-m", "--model",
        default="mlx-community/parakeet-tdt-0.6b-v2",
        help="Model identifier to use (default: mlx-community/parakeet-tdt-0.6b-v2)"
    )
    parser.add_argument(
        "--chunk-duration",
        type=int,
        default=300,
        help="Duration of each chunk in seconds for long files (default: 300 = 5 minutes)"
    )
    
    args = parser.parse_args()
    
    # Run transcription
    transcribe_audio(
        args.audio_file,
        args.output,
        args.model,
        args.chunk_duration
    )


if __name__ == "__main__":
    main()