#!/bin/bash
set -uo pipefail

if [ $# -ne 5 ]; then
    echo "Usage: $0 <dirs_file> <dest> <dest_path> <excludes_file> <ntfy_topic>"
    exit 1
fi

backup_dirs_file="$1"
rsync_dest="$2"
rsync_dest_path="$3"
rsync_excludes="$4"
ntfy_topic="$5"

# Helper function to format bytes to human readable
format_bytes() {
    local bytes=$1
    if (( bytes < 1024 )); then
        echo "${bytes} B"
    elif (( bytes < 1048576 )); then
        echo "$((bytes / 1024)) KB"
    elif (( bytes < 1073741824 )); then
        echo "$((bytes / 1048576)) MB"
    else
        echo "$((bytes / 1073741824)) GB"
    fi
}

# Helper function to format duration
format_duration() {
    local seconds=$1
    local hours=$((seconds / 3600))
    local minutes=$(((seconds % 3600) / 60))
    local secs=$((seconds % 60))

    if (( hours > 0 )); then
        echo "${hours}h ${minutes}m ${secs}s"
    elif (( minutes > 0 )); then
        echo "${minutes}m ${secs}s"
    else
        echo "${secs}s"
    fi
}

# Extract simple name for notifications
sync_name="${rsync_dest##*@}"  # Get hostname from user@host

# Create local log directory
log_dir="$HOME/logs/backup"
mkdir -p "$log_dir"

# Read directories from file (already relative paths)
dirs=()
dir_count=0
while IFS= read -r dir || [ -n "$dir" ]; do
    [[ -z "$dir" ]] && continue
    dirs+=("$dir")
    ((dir_count++)) || true
done < "$backup_dirs_file"

# Create temporary files for capturing output
sync_output=$(mktemp)
error_log=$(mktemp)
trap "rm -f $sync_output $error_log" EXIT

# Start timing
sync_start_time=$(date +%s)

echo "Starting rsync to $rsync_dest..."
echo "Syncing $dir_count directories..."

cd "$HOME"

# Test SSH connection first
if ! ssh -i ~/.ssh/id_ed25519 -o BatchMode=yes -o ConnectTimeout=10 "$rsync_dest" "ls" >/dev/null 2>&1; then
    echo "ERROR: Cannot connect to $rsync_dest via SSH without password"
    echo "Please set up SSH key authentication first"
    
    if [ -n "${ntfy_topic:-}" ]; then
        curl -s \
            -H "Title: ❌ Rsync Failed - $sync_name" \
            -H "Priority: 5" \
            -H "Tags: backup,rsync,$sync_name,error" \
            -d "SSH connection failed to $rsync_dest. Please set up SSH key authentication." \
            "https://ntfy.sh/$ntfy_topic"
    fi
    exit 1
fi

rsync -avz --delete --backup --relative \
    --backup-dir="rsync-deleted-$(date +%Y%m%d)" \
    --exclude-from="$rsync_excludes" \
    --stats \
    "${dirs[@]}" "$rsync_dest:$rsync_dest_path/" 2>&1 | tee "$sync_output"

if [ ${PIPESTATUS[0]} -eq 0 ]; then

    sync_end_time=$(date +%s)
    sync_duration=$((sync_end_time - sync_start_time))
    
    # Parse rsync stats
    files_transferred=0
    total_size=0
    total_transferred=0
    speedup=0

    if [ -s "$sync_output" ]; then
        # Extract stats from rsync output (handle both English and localized number formats)
        files_transferred=$(grep -E "Number of (regular )?files transferred:" "$sync_output" | awk -F: '{print $2}' | tr -d ' .' | head -1 || echo "0")
        total_size=$(grep -E "Total file size:" "$sync_output" | awk -F: '{print $2}' | awk '{print $1}' | tr -d ' .' || echo "0")
        total_transferred=$(grep -E "Total transferred file size:" "$sync_output" | awk -F: '{print $2}' | awk '{print $1}' | tr -d ' .' || echo "0")
        speedup=$(grep -E "total size .* speedup is" "$sync_output" | awk '{print $NF}' | tr -d ',' || echo "0")
    fi

    # Send success notification
    if [ -n "${ntfy_topic:-}" ]; then
        message="📁 Synced to $rsync_dest
⏱️ Duration: $(format_duration $sync_duration)
📊 Files: $files_transferred transferred
💾 Size: $(format_bytes $total_transferred) sent ($(format_bytes $total_size) total)
🚀 Speedup: ${speedup}x
📂 Directories: $dir_count synced"

        curl -s \
            -H "Title: ✅ Rsync Complete - $sync_name" \
            -H "Priority: 1" \
            -H "Tags: backup,rsync,$sync_name,success" \
            -d "$message" \
            "https://ntfy.sh/$ntfy_topic"
    fi

else
    # Sync failed
    sync_end_time=$(date +%s)
    sync_duration=$((sync_end_time - sync_start_time))

    # Extract error message from sync output
    error_message=$(grep -E "rsync error:|failed:" "$sync_output" 2>/dev/null | head -20)
    if [ -z "$error_message" ]; then
        error_message="Unknown error occurred during rsync"
    fi

    # Save error log locally
    local_log_file="$log_dir/rsync_error_${sync_name}_$(date +%Y%m%d_%H%M%S).log"
    {
        echo "=== RSYNC ERROR LOG ==="
        echo "Directories file: $backup_dirs_file"
        echo "Destination: $rsync_dest:$rsync_dest_path"
        echo "Start time: $(date -d @$sync_start_time)"
        echo "Duration: $(format_duration $sync_duration)"
        echo "Directories to sync: $dir_count"
        echo ""
        echo "=== ERROR OUTPUT ==="
        cat "$error_log" 2>/dev/null || echo "No error output captured"
        echo ""
        echo "=== RSYNC OUTPUT ==="
        cat "$sync_output" 2>/dev/null || echo "No rsync output captured"
    } > "$local_log_file"
    echo "Error log saved to: $local_log_file"

    if [ -n "${ntfy_topic:-}" ]; then
        # Send error notification with log file attached
        filename="rsync_error_${sync_name}_$(date +%Y%m%d_%H%M%S).log"
        curl -s \
            -T "$local_log_file" \
            -H "Filename: $filename" \
            -H "Title: ❌ Rsync Failed - $sync_name" \
            -H "Priority: 5" \
            -H "Tags: backup,rsync,$sync_name,error" \
            "https://ntfy.sh/$ntfy_topic"

        # Give ntfy time to process the attachment
        sleep 2
    fi

    exit 1
fi
