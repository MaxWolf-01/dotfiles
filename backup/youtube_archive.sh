#!/bin/bash

set -uo pipefail

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

# Create log directory and run log
log_dir="$HOME/logs/youtube"
mkdir -p "$log_dir"
run_log="$log_dir/run_$(date +%Y%m%d_%H%M%S).log"

echo "=== YouTube Download - $(date) ===" | tee -a "$run_log"
echo "Output dir: $output_dir" | tee -a "$run_log"
echo "" | tee -a "$run_log"

# Process each playlist
failed=0
failed_playlists=""
while IFS='|' read -r url format name; do
    [ -z "$url" ] && continue
    [ "${url:0:1}" = "#" ] && continue

    # Create directory: output_dir/audio|video/playlist_name/
    playlist_dir="$output_dir/$format/$name"
    mkdir -p "$playlist_dir"
    cd "$playlist_dir"

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

    echo "Downloading $name..." | tee -a "$run_log"
    "${cmd[@]}" > "$log_file" 2>&1
    exit_code=$?

    if [ $exit_code -ne 0 ]; then
        ((failed++))
        failed_playlists="${failed_playlists}${name} (exit ${exit_code}), "
        echo "  Failed (exit code: $exit_code)" | tee -a "$run_log"
    else
        echo "  Success" | tee -a "$run_log"
    fi
done < "$playlist_file"

# Count videos after
after_count=$(find "$output_dir" -name "*.mp4" -o -name "*.webm" -o -name "*.mkv" -o -name "*.wav" 2>/dev/null | wc -l || echo "0")
new_videos=$((after_count - before_count))

# Write summary to run log
echo "" | tee -a "$run_log"
echo "=== Summary ===" | tee -a "$run_log"
echo "New videos: $new_videos" | tee -a "$run_log"
echo "Failed playlists: $failed" | tee -a "$run_log"
[ $failed -gt 0 ] && echo "Failed: $failed_playlists" | tee -a "$run_log"
echo "Run log: $run_log" | tee -a "$run_log"

# Send notification
if [ -n "$ntfy_topic" ]; then
    if [ $failed -eq 0 ]; then
        if [ $new_videos -gt 0 ]; then
            curl -s -H "Title: YouTube Download Success" -H "Priority: 2" -H "Tags: youtube,success" \
                 -d "Downloaded $new_videos new videos" "https://ntfy.sh/$ntfy_topic" || true
        else
            curl -s -H "Title: YouTube Download Complete" -H "Priority: 1" -H "Tags: youtube,info" \
                 -d "No new videos. Log: $run_log" "https://ntfy.sh/$ntfy_topic" || true
        fi
    else
        curl -s -H "Title: YouTube Download - ${failed} Failed" -H "Priority: 3" -H "Tags: youtube,warning" \
             -d "$new_videos new videos. Failed: $failed_playlists See: $run_log" "https://ntfy.sh/$ntfy_topic" || true
    fi
fi
