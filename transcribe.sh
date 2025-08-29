#!/bin/bash

# Podcast Transcription Wrapper Script
# Automatically activates virtual environment and runs the transcription

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

# Run the transcription script with the virtual environment's Python
# Pass all command line arguments to the script
"$SCRIPT_DIR/venv/bin/python" "$SCRIPT_DIR/transcribe_podcast.py" "$@"