#!/bin/bash

# Raycast metadata (ignored when run from terminal)
# @raycast.schemaVersion 1
# @raycast.title Transcribe Podcast
# @raycast.mode fullOutput
# @raycast.icon 🎙️
# @raycast.packageName Podcast Tools
# @raycast.argument1 { "type": "text", "placeholder": "Path to audio file", "optional": false }
# @raycast.argument2 { "type": "text", "placeholder": "Output path (optional)", "optional": true }

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

# Function to parse Python output and display user-friendly messages
parse_output() {
    while IFS= read -r line; do
        case "$line" in
            *"Loading audio file:"*)
                # Extract filename from the path
                filename=$(echo "$line" | sed 's/.*Loading audio file: //')
                filename=$(basename "$filename")
                echo "📁 Opening: $filename"
                ;;
            *"Loading model:"*)
                echo "🎙️ Preparing transcription model..."
                ;;
            *"This may take a moment"*)
                echo "⏳ First-time setup: downloading model (this is a one-time process)"
                ;;
            *"Model loaded successfully"*)
                echo "✅ Ready to transcribe"
                ;;
            *"Audio duration:"*)
                # Extract just the time portion
                duration=$(echo "$line" | grep -oE '[0-9]+:[0-9]+:[0-9]+|[0-9]+:[0-9]+')
                # Convert to user-friendly format
                if [[ "$duration" =~ ^0:0?([0-9]+):([0-9]+)$ ]]; then
                    mins="${BASH_REMATCH[1]}"
                    echo "📊 Podcast length: $mins minutes"
                elif [[ "$duration" =~ ^([0-9]+):([0-9]+):([0-9]+)$ ]]; then
                    hours="${BASH_REMATCH[1]}"
                    mins="${BASH_REMATCH[2]}"
                    echo "📊 Podcast length: $hours hours $mins minutes"
                else
                    echo "📊 Podcast length: $duration"
                fi
                ;;
            *"Output will be saved to:"*)
                outpath=$(echo "$line" | sed 's/.*Output will be saved to: //')
                echo "🗂 Output: $outpath"
                ;;
            *"Sample rate:"*)
                # Skip technical details
                ;;
            *"Splitting into"*"chunks"*)
                chunks=$(echo "$line" | grep -oE '[0-9]+' | head -1)
                echo "📂 Breaking audio into $chunks segments for better processing"
                ;;
            *"Processing in chunks..."*)
                echo "🔄 Using memory-efficient processing for this long file"
                ;;
            *"Processing entire audio file..."*)
                echo "🔄 Processing audio (this may take a few minutes)"
                ;;
            *"Chunk "*"/"*)
                # Extract chunk progress information
                if [[ "$line" =~ Chunk[[:space:]]([0-9]+)/([0-9]+) ]]; then
                    current="${BASH_REMATCH[1]}"
                    total="${BASH_REMATCH[2]}"
                    percent=$((current * 100 / total))
                    
                    # Check for word count
                    if [[ "$line" =~ \(([0-9]+)[[:space:]]words\) ]]; then
                        words="${BASH_REMATCH[1]}"
                        echo "⏳ Segment $current of $total ($percent% complete) - $words words transcribed"
                    elif [[ "$line" =~ "✓" ]]; then
                        echo "⏳ Segment $current of $total ($percent% complete) - completed"
                    else
                        echo "⏳ Processing segment $current of $total ($percent% complete)"
                    fi
                fi
                ;;
            *"Transcript saved to:"*)
                # Extract the file path
                filepath=$(echo "$line" | sed 's/.*Transcript saved to: //')
                echo "💾 Transcript saved to: $filepath"
                ;;
            *"Transcript contains"*"words"*)
                # Extract word count
                words=$(echo "$line" | grep -oE '[0-9,]+')
                echo "📝 Total transcript length: $words words"
                ;;
            *"Processing speed:"*)
                # Extract speed ratio
                speed=$(echo "$line" | grep -oE '[0-9]+\.[0-9]+')
                echo "⚡ Processed at ${speed}x real-time speed"
                ;;
            *"Transcription completed in "*)
                t=$(echo "$line" | sed 's/.*Transcription completed in //')
                echo "⏱ Completed in $t"
                ;;
            *"Error"*|*"error"*)
                # Show errors but in a friendly way
                echo "⚠️ Issue encountered: $line"
                ;;
            *"Warning:"*)
                # Show our script warnings as friendly output
                echo "⚠️ $line"
                ;;
            *)
                # Skip other technical output
                ;;
        esac
    done
}

# Start message
echo "🎙️ Starting podcast transcription..."
echo ""

# Parse and normalize arguments (expand ~ and relative paths)
DRY_RUN=0
args=("$@")
new_args=()
audio_set=0
expect_output_value=0
output_set=0

for ((i=0; i<${#args[@]}; i++)); do
    token="${args[$i]}"

    # Handle dry-run flag
    if [[ "$token" == "--dry-run" ]]; then
        DRY_RUN=1
        continue
    fi

    # Handle -o=VALUE or --output=VALUE forms
    if [[ "$token" == -o=* || "$token" == --output=* ]]; then
        val="${token#*=}"
        # Ignore empty output values
        if [[ -z "$val" ]]; then
            continue
        fi
        # Expand ~ and relative path
        case "$val" in
            ~*) val="${val/#\~/$HOME}" ;;
        esac
        if [[ ! "$val" = /* ]]; then
            val="$(pwd)/$val"
        fi
        if [[ "$token" == -o=* ]]; then
            new_args+=("-o" "$val")
        else
            new_args+=("--output" "$val")
        fi
        output_set=1
        continue
    fi

    # If previous token was -o/--output, expand this value
    if [[ $expect_output_value -eq 1 ]]; then
        val="$token"
        # Ignore empty output values
        if [[ -z "$val" ]]; then
            expect_output_value=0
            continue
        fi
        case "$val" in
            ~*) val="${val/#\~/$HOME}" ;;
        esac
        if [[ ! "$val" = /* ]]; then
            val="$(pwd)/$val"
        fi
        new_args+=("$val")
        expect_output_value=0
        output_set=1
        continue
    fi

    # Detect -o or --output expecting a value next
    if [[ "$token" == "-o" || "$token" == "--output" ]]; then
        new_args+=("$token")
        expect_output_value=1
        continue
    fi

    # First positional arg is the audio file; expand it
    if [[ $audio_set -eq 0 && "$token" != -* ]]; then
        # Ignore empty first positional (can happen if Raycast passes an empty optional)
        if [[ -z "$token" ]]; then
            continue
        fi
        val="$token"
        case "$val" in
            ~*) val="${val/#\~/$HOME}" ;;
        esac
        if [[ ! "$val" = /* ]]; then
            val="$(pwd)/$val"
        fi
        new_args+=("$val")
        audio_set=1
        continue
    fi

    # If a second positional arg is provided (common via Raycast), treat it as output path
    if [[ $audio_set -eq 1 && $output_set -eq 0 && "$token" != -* ]]; then
        # Ignore empty second positional (Raycast optional argument not provided)
        if [[ -z "$token" ]]; then
            continue
        fi
        val="$token"
        case "$val" in
            ~*) val="${val/#\~/$HOME}" ;;
        esac
        if [[ ! "$val" = /* ]]; then
            val="$(pwd)/$val"
        fi
        new_args+=("-o" "$val")
        output_set=1
        continue
    fi

    # Pass through everything else
    new_args+=("$token")
done

if [[ $DRY_RUN -eq 1 ]]; then
    echo "🎙️ Transcribe Podcast (dry-run)"
    # Surface key bits from parsed args
    audio_path="(none)"
    output_path="(default .md next to audio)"
    model="(default)"
    chunk="(default)"
    for ((i=0; i<${#new_args[@]}; i++)); do
        t="${new_args[$i]}"
        if [[ $i -eq 0 && ! "$t" =~ ^- ]]; then
            audio_path="$t"
        elif [[ "$t" == "-o" || "$t" == "--output" ]]; then
            output_path="${new_args[$((i+1))]}"
        elif [[ "$t" == "-m" || "$t" == "--model" ]]; then
            model="${new_args[$((i+1))]}"
        elif [[ "$t" == "--chunk-duration" ]]; then
            chunk="${new_args[$((i+1))]} seconds"
        fi
    done
    echo "- Audio: $audio_path"
    echo "- Output: $output_path"
    echo "- Model: $model"
    echo "- Chunk duration: $chunk"
    echo ""
    printf "Would execute:\n  %q -u %q" "$SCRIPT_DIR/venv/bin/python" "$SCRIPT_DIR/transcribe_podcast.py"
    for a in "${new_args[@]}"; do printf " %q" "$a"; done
    echo ""
    exit 0
fi

# Ensure an audio path was provided
if [[ $audio_set -eq 0 ]]; then
    echo "❌ No audio file provided. Please supply a path to an audio file."
    exit 1
fi

# Run Python script (unbuffered) and pipe through parser
# Use 2>&1 to capture both stdout and stderr
"$SCRIPT_DIR/venv/bin/python" -u "$SCRIPT_DIR/transcribe_podcast.py" "${new_args[@]}" 2>&1 | parse_output

# Check exit status (use PIPESTATUS to get Python script's exit code)
if [ ${PIPESTATUS[0]} -eq 0 ]; then
    echo ""
    echo "✅ Transcription complete!"
else
    echo ""
    echo "❌ Transcription failed. Please check the audio file and try again."
    exit 1
fi
