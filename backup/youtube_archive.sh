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

# Create log directory and run log
log_dir="$HOME/logs/youtube"
mkdir -p "$log_dir"
run_log="$log_dir/run_$(date +%Y%m%d_%H%M%S).log"

echo "=== YouTube Download - $(date) ===" | tee -a "$run_log"
echo "Output dir: $output_dir" | tee -a "$run_log"
echo "" | tee -a "$run_log"

# Process each playlist
all_downloaded_titles=()
failed_playlists=""
error_unavailable=0
error_copyright=0
error_deleted=0
error_other=0

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

    # Parse log for downloaded videos and errors
    downloaded_titles=()
    while IFS= read -r line; do
        # Extract downloaded video titles (look for [download] lines with actual downloads)
        if [[ "$line" =~ \[download\]\ Destination:\ (.+)\.(wav|mp4|webm|mkv)$ ]]; then
            filename=$(basename "${BASH_REMATCH[1]}")
            # Clean up yt-dlp filename format: remove video ID suffix
            title=$(echo "$filename" | sed -E 's/ \[[a-zA-Z0-9_-]{11}\]$//')
            downloaded_titles+=("$title")
        fi

        # Count errors by type
        if [[ "$line" =~ ERROR:.*unavailable|not\ available ]]; then
            ((error_unavailable++))
        elif [[ "$line" =~ ERROR:.*copyright\ claim ]]; then
            ((error_copyright++))
        elif [[ "$line" =~ ERROR:.*removed|deleted ]]; then
            ((error_deleted++))
        elif [[ "$line" =~ ^ERROR: ]]; then
            ((error_other++))
        fi
    done < "$log_file"

    # Determine if this is a real failure
    is_failure=false
    if [ $exit_code -ne 0 ] && [ ${#downloaded_titles[@]} -eq 0 ]; then
        # Exit code 1 AND no downloads = real failure
        is_failure=true
    fi

    if [ "$is_failure" = true ]; then
        failed_playlists="${failed_playlists}${name}, "
        echo "  Failed (exit code: $exit_code)" | tee -a "$run_log"
    else
        if [ ${#downloaded_titles[@]} -gt 0 ]; then
            echo "  Downloaded ${#downloaded_titles[@]} video(s)" | tee -a "$run_log"
            all_downloaded_titles+=("${downloaded_titles[@]}")
        else
            echo "  No new videos" | tee -a "$run_log"
        fi
    fi
done < "$playlist_file"

# Write summary to run log
echo "" | tee -a "$run_log"
echo "=== Summary ===" | tee -a "$run_log"
echo "Total downloaded: ${#all_downloaded_titles[@]}" | tee -a "$run_log"
if [ ${#all_downloaded_titles[@]} -gt 0 ]; then
    echo "Downloaded videos:" | tee -a "$run_log"
    printf '  - %s\n' "${all_downloaded_titles[@]}" | tee -a "$run_log"
fi

error_count=$((error_unavailable + error_copyright + error_deleted + error_other))
if [ $error_count -gt 0 ]; then
    echo "Errors encountered:" | tee -a "$run_log"
    [ $error_unavailable -gt 0 ] && echo "  - Unavailable: $error_unavailable" | tee -a "$run_log"
    [ $error_copyright -gt 0 ] && echo "  - Copyright: $error_copyright" | tee -a "$run_log"
    [ $error_deleted -gt 0 ] && echo "  - Deleted/Removed: $error_deleted" | tee -a "$run_log"
    [ $error_other -gt 0 ] && echo "  - Other: $error_other" | tee -a "$run_log"
fi

if [ -n "$failed_playlists" ]; then
    echo "Failed playlists: ${failed_playlists%, }" | tee -a "$run_log"
fi
echo "Run log: $run_log" | tee -a "$run_log"

# Send notification
if [ -n "$ntfy_topic" ]; then
    # Build notification message
    msg=""
    if [ ${#all_downloaded_titles[@]} -gt 0 ]; then
        msg="Downloaded ${#all_downloaded_titles[@]} video(s):\n"
        for title in "${all_downloaded_titles[@]}"; do
            msg+="• $title\n"
        done
    else
        msg="No new videos downloaded.\n"
    fi

    if [ $error_count -gt 0 ]; then
        msg+="\nErrors: "
        error_parts=()
        [ $error_unavailable -gt 0 ] && error_parts+=("${error_unavailable} unavailable")
        [ $error_copyright -gt 0 ] && error_parts+=("${error_copyright} copyright")
        [ $error_deleted -gt 0 ] && error_parts+=("${error_deleted} deleted")
        [ $error_other -gt 0 ] && error_parts+=("${error_other} other")
        msg+=$(IFS=", "; echo "${error_parts[*]}")
    fi

    if [ -n "$failed_playlists" ]; then
        msg+="\n\nFailed: ${failed_playlists%, }"
    fi

    # Determine priority and title
    if [ -n "$failed_playlists" ]; then
        # Real failures get warning priority
        title="YouTube Download - Failures"
        priority=3
        tags="youtube,warning"
    elif [ ${#all_downloaded_titles[@]} -gt 0 ]; then
        # Downloads succeeded
        title="YouTube Download - ${#all_downloaded_titles[@]} New"
        priority=2
        tags="youtube,success"
    else
        # Nothing new
        title="YouTube Download - Up to Date"
        priority=1
        tags="youtube,info"
    fi

    curl -s -H "Title: $title" -H "Priority: $priority" -H "Tags: $tags" \
         -d "$msg" "https://ntfy.sh/$ntfy_topic" || true
fi
