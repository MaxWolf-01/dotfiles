#!/usr/bin/env bash

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
total_error_unavailable=0
total_error_copyright=0
total_error_deleted=0
total_error_other=0
total_errors_archived=0
total_errors_lost=0

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
        --download-archive archive.txt
        --continue
        --sleep-interval 5 --max-sleep-interval 10
    )
    if [ -n "${YOUTUBE_COOKIES:-}" ] && [ -f "$YOUTUBE_COOKIES" ]; then
        cmd+=(--cookies "$YOUTUBE_COOKIES")
    else
        cmd+=(--cookies-from-browser firefox)
    fi
    cmd+=("$url")

    log_file="$log_dir/${name}_$(date +%Y%m%d_%H%M%S).log"

    echo "Downloading $name..." | tee -a "$run_log"
    "${cmd[@]}" > "$log_file" 2>&1
    exit_code=$?

    # Parse log for downloaded videos and errors
    downloaded_titles=()
    pl_error_unavailable=0
    pl_error_copyright=0
    pl_error_deleted=0
    pl_error_other=0
    pl_error_ids=()

    while IFS= read -r line; do
        # Extract downloaded video titles (look for [download] lines with actual downloads)
        if [[ "$line" =~ \[download\]\ Destination:\ (.+)\.(wav|mp4|webm|mkv)$ ]]; then
            filename=$(basename "${BASH_REMATCH[1]}")
            # Clean up yt-dlp filename format: remove video ID suffix
            title=$(echo "$filename" | sed -E 's/ \[[a-zA-Z0-9_-]{11}\]$//')
            downloaded_titles+=("$title")
        fi

        # Extract video ID from error lines (11-char base64url, [youtube] extractor only)
        if [[ "$line" =~ ERROR:.*\[youtube\]\ ([a-zA-Z0-9_-]{11}): ]]; then
            pl_error_ids+=("${BASH_REMATCH[1]}")
        fi

        # Count errors by type
        if [[ "$line" =~ ERROR:.*(unavailable|not\ available) ]]; then
            ((pl_error_unavailable++))
        elif [[ "$line" =~ ERROR:.*(copyright\ claim) ]]; then
            ((pl_error_copyright++))
        elif [[ "$line" =~ ERROR:.*(removed|deleted|Private\ video|members-only|Join\ this\ channel) ]]; then
            ((pl_error_deleted++))
        elif [[ "$line" =~ ^ERROR: ]]; then
            ((pl_error_other++))
        fi
    done < "$log_file"

    # Cross-reference error video IDs with archive.txt
    pl_errors_archived=0
    pl_errors_lost=0
    for vid_id in "${pl_error_ids[@]}"; do
        if grep -q "youtube $vid_id" "$playlist_dir/archive.txt" 2>/dev/null; then
            ((pl_errors_archived++))
        else
            ((pl_errors_lost++))
            # Append to persistent lost.txt (first-seen only, deduped by ID)
            if ! grep -q "$vid_id" "$playlist_dir/lost.txt" 2>/dev/null; then
                echo "$(date +%Y-%m-%d) $vid_id https://youtube.com/watch?v=$vid_id" >> "$playlist_dir/lost.txt"
            fi
        fi
    done

    # Determine if this is a real failure
    # yt-dlp exits 1 when any video is unavailable — that's expected, not a script failure.
    # Only flag as failure when there are unexpected errors.
    is_failure=false
    if [ $exit_code -ne 0 ]; then
        pl_expected=$((pl_error_unavailable + pl_error_copyright + pl_error_deleted))
        if [ $pl_error_other -gt 0 ]; then
            is_failure=true
        elif [ $pl_expected -eq 0 ] && [ ${#downloaded_titles[@]} -eq 0 ]; then
            # Non-zero exit, no recognized errors, no downloads = unknown failure
            is_failure=true
        fi
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
        if [ ${#pl_error_ids[@]} -gt 0 ]; then
            echo "  Errors: ${#pl_error_ids[@]} videos (${pl_errors_archived} archived, ${pl_errors_lost} never captured)" | tee -a "$run_log"
        fi
    fi

    # Accumulate into global counters
    total_error_unavailable=$((total_error_unavailable + pl_error_unavailable))
    total_error_copyright=$((total_error_copyright + pl_error_copyright))
    total_error_deleted=$((total_error_deleted + pl_error_deleted))
    total_error_other=$((total_error_other + pl_error_other))
    total_errors_archived=$((total_errors_archived + pl_errors_archived))
    total_errors_lost=$((total_errors_lost + pl_errors_lost))
done < "$playlist_file"

# Write summary to run log
echo "" | tee -a "$run_log"
echo "=== Summary ===" | tee -a "$run_log"
echo "Total downloaded: ${#all_downloaded_titles[@]}" | tee -a "$run_log"
if [ ${#all_downloaded_titles[@]} -gt 0 ]; then
    echo "Downloaded videos:" | tee -a "$run_log"
    printf '  - %s\n' "${all_downloaded_titles[@]}" | tee -a "$run_log"
fi

error_count=$((total_error_unavailable + total_error_copyright + total_error_deleted + total_error_other))
if [ $error_count -gt 0 ]; then
    echo "Errors encountered:" | tee -a "$run_log"
    [ $total_error_unavailable -gt 0 ] && echo "  - Unavailable: $total_error_unavailable" | tee -a "$run_log"
    [ $total_error_copyright -gt 0 ] && echo "  - Copyright: $total_error_copyright" | tee -a "$run_log"
    [ $total_error_deleted -gt 0 ] && echo "  - Deleted/Removed: $total_error_deleted" | tee -a "$run_log"
    [ $total_error_other -gt 0 ] && echo "  - Other: $total_error_other" | tee -a "$run_log"
    echo "  Never captured: ${total_errors_lost}" | tee -a "$run_log"
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
        gone=$((total_error_unavailable + total_error_copyright + total_error_deleted))
        msg+="\n${gone} gone"
        [ $total_error_other -gt 0 ] && msg+=", ${total_error_other} unexpected errors"
    fi

    if [ -n "$failed_playlists" ]; then
        msg+="\n\nFailed: ${failed_playlists%, }"
    fi

    # Determine priority and title
    if [ -n "$failed_playlists" ]; then
        title="YouTube Download - Failures"
        priority=3
        tags="youtube,warning"
    elif [ ${#all_downloaded_titles[@]} -gt 0 ]; then
        title="YouTube Download - ${#all_downloaded_titles[@]} New"
        priority=2
        tags="youtube,success"
    else
        title="YouTube Download - Up to Date"
        priority=1
        tags="youtube,info"
    fi

    curl -s -H "Title: $title" -H "Priority: $priority" -H "Tags: $tags" \
         -d "$msg" "https://ntfy.sh/$ntfy_topic" || true
fi
