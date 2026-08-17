#!/usr/bin/env bash
# Download the configured YouTube playlists.
#
# Sends no notifications: a new video, a video gone from YouTube, and a quiet
# day are all things to read later, not to be told about. Each run appends its
# counts to the run log instead, and the overdue watchdog is what speaks up
# when the runs stop landing.

set -uo pipefail

# Reached relative to this script, not through PATH: the systemd unit pins its
# own PATH and it does not carry ~/bin. The unit also runs sandboxed, so
# nix/nixos/pc/youtube-download.nix has to bind this path in.
run_log_bin="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../bin/run-log"

# The run log is a record, not a control flow: if writing it fails, run-log says
# so on stderr and the download carries on. A missing line is what the overdue
# watchdog exists to catch.
log_run() {
    "$run_log_bin" youtube-download "$@" || true
}

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
    log_run fail --reason "playlist file not found: $playlist_file"
    exit 1
fi

# Check yt-dlp is available
if ! command -v yt-dlp &> /dev/null; then
    echo "yt-dlp not found. Run: ./setup ytdlp"
    log_run fail --reason "yt-dlp not on PATH"
    exit 1
fi

# Create log directory and per-run summary log
log_dir="$HOME/logs/youtube"
mkdir -p "$log_dir"
summary_log="$log_dir/run_$(date +%Y%m%d_%H%M%S).log"

echo "=== YouTube Download - $(date) ===" | tee -a "$summary_log"
echo "Output dir: $output_dir" | tee -a "$summary_log"
echo "" | tee -a "$summary_log"

# Process each playlist
all_downloaded_titles=()
failed_playlists=()
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

    echo "Downloading $name..." | tee -a "$summary_log"
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
        failed_playlists+=("$name")
        echo "  Failed (exit code: $exit_code)" | tee -a "$summary_log"
    else
        if [ ${#downloaded_titles[@]} -gt 0 ]; then
            echo "  Downloaded ${#downloaded_titles[@]} video(s)" | tee -a "$summary_log"
            all_downloaded_titles+=("${downloaded_titles[@]}")
        else
            echo "  No new videos" | tee -a "$summary_log"
        fi
        if [ ${#pl_error_ids[@]} -gt 0 ]; then
            echo "  Errors: ${#pl_error_ids[@]} videos (${pl_errors_archived} archived, ${pl_errors_lost} never captured)" | tee -a "$summary_log"
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

# Write the run summary
echo "" | tee -a "$summary_log"
echo "=== Summary ===" | tee -a "$summary_log"
echo "Total downloaded: ${#all_downloaded_titles[@]}" | tee -a "$summary_log"
if [ ${#all_downloaded_titles[@]} -gt 0 ]; then
    echo "Downloaded videos:" | tee -a "$summary_log"
    printf '  - %s\n' "${all_downloaded_titles[@]}" | tee -a "$summary_log"
fi

error_count=$((total_error_unavailable + total_error_copyright + total_error_deleted + total_error_other))
if [ $error_count -gt 0 ]; then
    echo "Errors encountered:" | tee -a "$summary_log"
    [ $total_error_unavailable -gt 0 ] && echo "  - Unavailable: $total_error_unavailable" | tee -a "$summary_log"
    [ $total_error_copyright -gt 0 ] && echo "  - Copyright: $total_error_copyright" | tee -a "$summary_log"
    [ $total_error_deleted -gt 0 ] && echo "  - Deleted/Removed: $total_error_deleted" | tee -a "$summary_log"
    [ $total_error_other -gt 0 ] && echo "  - Other: $total_error_other" | tee -a "$summary_log"
    echo "  Never captured: ${total_errors_lost}" | tee -a "$summary_log"
fi

if [ ${#failed_playlists[@]} -gt 0 ]; then
    echo "Failed playlists: ${failed_playlists[*]}" | tee -a "$summary_log"
fi
echo "Log: $summary_log" | tee -a "$summary_log"

# "gone" is the expected attrition — videos YouTube no longer serves. Whether
# that cost us anything is `never_captured`: the ones we never had a copy of.
stats=$(jq -n \
    --argjson downloaded "${#all_downloaded_titles[@]}" \
    --argjson gone "$((total_error_unavailable + total_error_copyright + total_error_deleted))" \
    --argjson errors_other "$total_error_other" \
    --argjson already_archived "$total_errors_archived" \
    --argjson never_captured "$total_errors_lost" \
    --arg log "$summary_log" \
    --args '$ARGS.named + {playlists_failed: $ARGS.positional}' \
    -- "${failed_playlists[@]}")

if [ ${#failed_playlists[@]} -eq 0 ]; then
    log_run ok --stats "$stats"
else
    log_run fail --reason "playlists failed: $(IFS=,; echo "${failed_playlists[*]}")" --stats "$stats"
fi
