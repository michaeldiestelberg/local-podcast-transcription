#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Transcribe Podcast
# @raycast.mode silent

# Optional parameters:
# @raycast.icon 🎙️
# @raycast.packageName Podcast Tools
# @raycast.argument1 { "type": "text", "placeholder": "Path to audio file", "optional": false }
# @raycast.argument2 { "type": "text", "placeholder": "Output path (optional)", "optional": true }

# Documentation:
# @raycast.description Transcribe podcast audio files to markdown using parakeet-mlx
# @raycast.author Michael Diestelberg
# @raycast.authorURL https://github.com/michaeldiestelberg

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Check if virtual environment exists
if [ ! -d "$SCRIPT_DIR/venv" ]; then
    echo "Error: Virtual environment not found!"
    echo ""
    echo "Please set up the environment first:"
    echo "  cd $SCRIPT_DIR"
    echo "  python3 -m venv venv"
    echo "  source venv/bin/activate"
    echo "  pip install -r requirements.txt"
    exit 1
fi

# Check if requirements are installed
if [ ! -f "$SCRIPT_DIR/venv/bin/python" ]; then
    echo "Error: Virtual environment seems incomplete!"
    echo "Please reinstall the virtual environment."
    exit 1
fi

# Expand the path to handle ~ and relative paths
AUDIO_FILE="${1/#\~/$HOME}"
if [[ ! "$AUDIO_FILE" = /* ]]; then
    AUDIO_FILE="$(pwd)/$AUDIO_FILE"
fi

# Check if the audio file exists
if [ ! -f "$AUDIO_FILE" ]; then
    echo "Error: Audio file not found: $AUDIO_FILE"
    exit 1
fi

# Build the command
CMD="$SCRIPT_DIR/venv/bin/python $SCRIPT_DIR/transcribe_podcast.py \"$AUDIO_FILE\""

# Add output path if provided
if [ -n "$2" ]; then
    OUTPUT_FILE="${2/#\~/$HOME}"
    if [[ ! "$OUTPUT_FILE" = /* ]]; then
        OUTPUT_FILE="$(pwd)/$OUTPUT_FILE"
    fi
    CMD="$CMD -o \"$OUTPUT_FILE\""
fi

# Run the transcription
echo "🎙️ Starting transcription of: $(basename "$AUDIO_FILE")"
echo "This may take a few minutes..."
echo ""

# Execute the command
eval $CMD

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Transcription complete!"
else
    echo ""
    echo "❌ Transcription failed. Check the error messages above."
    exit 1
fi