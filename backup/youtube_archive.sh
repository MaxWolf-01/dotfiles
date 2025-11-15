#!/bin/bash

set -euo pipefail

playlist_file="${1:-}"
output_dir="${2:-}"

if [ -z "$playlist_file" ] || [ -z "$output_dir" ]; then
    echo "Usage: $0 <playlist_file> <output_dir>"
    echo "Playlist file format: URL|(audio|video)|name"
    echo "Example: https://youtube.com/playlist?list=XXX|audio|MusicPlaylist"
    exit 1
fi

if [ ! -f "$playlist_file" ]; then
    echo "Playlist file not found: $playlist_file"
    exit 1
fi

ntfy_topic="${NTFY_TOPIC:-}"

# Check yt-dlp is available
if ! command -v yt-dlp &> /dev/null; then
    echo "yt-dlp not found. Run: ./setup ytdlp"
    exit 1
fi

# Count videos before
before_count=$(find "$output_dir" -name "*.mp4" -o -name "*.webm" -o -name "*.mkv" -o -name "*.wav" 2>/dev/null | wc -l || echo "0")

# Create log directory
log_dir="$HOME/logs/youtube"
mkdir -p "$log_dir"

# Process each playlist
failed=0
while IFS='|' read -r url format name; do
    [ -z "$url" ] && continue
    [ "${url:0:1}" = "#" ] && continue

    # Create directory: output_dir/audio|video/playlist_name/
    playlist_dir="$output_dir/$format/$name"
    mkdir -p "$playlist_dir"
    cd "$playlist_dir"

    echo "Downloading $name..."

    # Build yt-dlp command based on format
    if [ "$format" = "audio" ]; then
        cmd=(yt-dlp -f "ba/b" --extract-audio --audio-format wav --audio-quality 0)
    else
        cmd=(yt-dlp --format "bv[height<=720]+ba/b[height<=720]")
    fi

    # Common options
    cmd+=(
        --cookies-from-browser firefox
        --download-archive archive.txt
        --continue
        "$url"
    )

    log_file="$log_dir/${name}_$(date +%Y%m%d_%H%M%S).log"

    if output=$("${cmd[@]}" 2>&1 | tee "$log_file"); then
        echo "✓ $name"
    else
        ((failed++))
        error=$(echo "$output" | tail -n 10)
        echo "✗ $name FAILED"
        echo "$error"
        echo "Full log: $log_file"

        if [ -n "$ntfy_topic" ]; then
            curl -s -H "Title: YouTube Download Failed: $name" -H "Priority: 4" -H "Tags: youtube,error" \
                 -d "$error" "https://ntfy.sh/$ntfy_topic" || true
        fi
    fi
done < "$playlist_file"

# Count videos after
after_count=$(find "$output_dir" -name "*.mp4" -o -name "*.webm" -o -name "*.mkv" -o -name "*.wav" 2>/dev/null | wc -l || echo "0")
new_videos=$((after_count - before_count))

# Send notification
if [ -n "$ntfy_topic" ]; then
    if [ $failed -eq 0 ]; then
        if [ $new_videos -gt 0 ]; then
            curl -s -H "Title: YouTube Download Success" -H "Priority: 2" -H "Tags: youtube,success" \
                 -d "Downloaded $new_videos new videos" "https://ntfy.sh/$ntfy_topic" || true
        else
            curl -s -H "Title: YouTube Download Complete" -H "Priority: 1" -H "Tags: youtube,info" \
                 -d "No new videos found" "https://ntfy.sh/$ntfy_topic" || true
        fi
    else
        curl -s -H "Title: YouTube Download Partial" -H "Priority: 3" -H "Tags: youtube,warning" \
             -d "$failed playlists failed, $new_videos new videos" "https://ntfy.sh/$ntfy_topic" || true
    fi
fi

# Print summary
echo ""
echo "=== Summary ==="
echo "New videos: $new_videos"
echo "Failed playlists: $failed"
[ -n "$log_dir" ] && echo "Logs: $log_dir"
