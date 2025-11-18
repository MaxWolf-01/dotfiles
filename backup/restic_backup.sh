#!/bin/bash
# Restic backup wrapper with enhanced notifications

set -uo pipefail

# Usage: restic_backup.sh <config_file>
#
# Expected config variables:
# repo_path - Path to restic repository
# password_command - Command to output password (e.g., "sops -d /path/to/password")
# backup_dirs_file - File containing directories to backup (relative paths)
# base_path - Base path to prepend to directories (e.g., $HOME or $HOME/data-mirror/laptop)
# exclude_file - (optional) File containing exclude patterns
# compression - Compression level (max, auto, off)
# keep_last - Number of latest snapshots to keep
# keep_daily - Number of daily snapshots to keep
# keep_weekly - Number of weekly snapshots to keep
# keep_monthly - Number of monthly snapshots to keep
# check_data - (optional) "true", "false", or percentage like "5%" (default: false)
# ntfy_topic - (optional) Ntfy topic for notifications
# show_progress - (optional) "true" or "false" to show backup progress (default: false)

# Helper to send failure notification and exit
send_failure_ntfy() {
    local error_message="$1"
    local config_name="$2"
    local ntfy_topic="${3:-}"

    if [ -n "$ntfy_topic" ]; then
        curl -s \
            -H "Title: ❌ Restic Backup Failed - $config_name" \
            -H "Priority: 5" \
            -H "Tags: backup,restic,$config_name,error" \
            -d "$error_message" \
            "https://ntfy.sh/$ntfy_topic"
    fi
    echo "$error_message"
    exit 1
}

config_file="${1:-}"
if [ -z "$config_file" ] || [ ! -f "$config_file" ]; then
    echo "Usage: $0 <config_file>"
    exit 1
fi

source "$config_file"

# Extract config name early for error notifications
config_name="$(basename "$(dirname "$config_file")")-$(basename "$config_file" .conf)"

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

# Create local log directory
log_dir="$HOME/logs/backup"
mkdir -p "$log_dir"

# Check if repository exists
timestamp=$(date +%Y%m%d_%H%M%S)
repo_check_log="$log_dir/repo_check_${config_name}_${timestamp}.log"
if ! restic --repo "$repo_path" --password-command "$password_command" cat config >"$repo_check_log" 2>&1; then
    echo "Initializing restic repository at $repo_path"
    init_log="$log_dir/repo_init_${config_name}_${timestamp}.log"
    if ! restic init --repo "$repo_path" --password-command "$password_command" >"$init_log" 2>&1; then
        error_details=$(cat "$init_log" "$repo_check_log" 2>/dev/null)
        send_failure_ntfy "Failed to initialize restic repository at $repo_path

ERROR OUTPUT:
$error_details

Logs: $repo_check_log, $init_log
Config: $config_file
Repo: $repo_path
Password command: $password_command" "$config_name" "${ntfy_topic:-}"
    fi
fi

# Validate base_path is set
if [ -z "${base_path:-}" ]; then
    send_failure_ntfy "base_path not defined in config file" "$config_name" "${ntfy_topic:-}"
fi

# Create temporary files for capturing output
backup_output=$(mktemp)
error_log=$(mktemp)
trap "rm -f $backup_output $error_log" EXIT

# Run backup with JSON output
echo "Starting backup for $config_name..."
backup_start_time=$(date +%s)

export RESTIC_PROGRESS_FPS=0.05 # every 20s
# Determine if we should calculate progress estimate (default: false for cron jobs)
if [ "${show_progress:-false}" = "true" ]; then
    scan_option=""
else
    scan_option="--no-scan"
fi

# Build exclude options if exclude file(s) are specified
exclude_opts=""
if [ -n "${exclude_file:-}" ]; then
    # Support multiple exclude files separated by colons
    IFS=':' read -ra EXCLUDE_FILES <<< "$exclude_file"
    for ef in "${EXCLUDE_FILES[@]}"; do
        if [ -f "$ef" ]; then
            exclude_opts="$exclude_opts --exclude-file=$ef"
            echo "Using exclude file: $ef"
        fi
    done
fi

if sed "s|^|$base_path/|" "$backup_dirs_file" | \
   restic --repo "$repo_path" backup \
    --option compression="$compression" \
    --files-from-verbatim - \
    --password-command "$password_command" \
    $exclude_opts \
    $scan_option \
    --json 2>"$error_log" | tee "$backup_output"; then

    backup_success=true
    backup_end_time=$(date +%s)
    backup_duration=$((backup_end_time - backup_start_time))

    # Parse JSON output to extract metrics
    snapshot_id=""
    files_new=0
    files_changed=0
    files_unmodified=0
    total_files_processed=0
    data_added=0
    data_added_packed=0
    total_bytes_processed=0

    # Read the last summary line which contains the backup summary
    if [ -s "$backup_output" ]; then
        summary_json=$(grep '"message_type":"summary"' "$backup_output" | tail -1)
        if [ -n "$summary_json" ]; then
            snapshot_id=$(echo "$summary_json" | jq -r '.snapshot_id // empty' | cut -c1-8)
            files_new=$(echo "$summary_json" | jq -r '.files_new // 0')
            files_changed=$(echo "$summary_json" | jq -r '.files_changed // 0')
            files_unmodified=$(echo "$summary_json" | jq -r '.files_unmodified // 0')
            total_files_processed=$(echo "$summary_json" | jq -r '.total_files_processed // 0')
            data_added=$(echo "$summary_json" | jq -r '.data_added // 0')
            data_added_packed=$(echo "$summary_json" | jq -r '.data_added_packed // 0')
            total_bytes_processed=$(echo "$summary_json" | jq -r '.total_bytes_processed // 0')
        fi
    fi

    # Calculate compression savings if we have the data
    compression_info=""
    if [ "$data_added" -gt 0 ] && [ "$data_added_packed" -gt 0 ]; then
        saved_percentage=$(( (data_added - data_added_packed) * 100 / data_added ))
        compression_info=" (saved ${saved_percentage}%)"
    fi

    # Run forget and prune
    echo "Pruning old snapshots..."
    restic --repo "$repo_path" forget --prune \
        --keep-last "$keep_last" \
        --keep-daily "$keep_daily" \
        --keep-weekly "$keep_weekly" \
        --keep-monthly "$keep_monthly" \
        --password-command "$password_command" >/dev/null 2>&1

    # Determine check arguments based on config
    check_args=""
    check_description="basic"
    if [ "${check_data:-false}" = "true" ]; then
        check_args="--read-data"
        check_description="full"
    elif [ "${check_data:-false}" != "false" ]; then
        check_args="--read-data-subset=$check_data"
        check_description="$check_data of data"
    fi

    # Run repository check
    echo "Checking repository integrity..."
    if restic check --repo "$repo_path" --password-command "$password_command" $check_args >/dev/null 2>&1; then
        check_status="passed"
    else
        check_status="FAILED"
        backup_success=false
    fi

    # Send notification
    if [ -n "${ntfy_topic:-}" ]; then
        if [ "$backup_success" = true ]; then
            # Format success message
            message="📦 Snapshot ${snapshot_id} created
⏱️ Duration: $(format_duration $backup_duration)
📊 Files: $total_files_processed processed ($files_new new, $files_changed changed)
💾 Size: $(format_bytes $data_added) added ($(format_bytes $data_added_packed)$compression_info)
🔍 Integrity: $check_description check $check_status"

            curl -s \
                -H "Title: ✅ Restic Backup Complete - $config_name" \
                -H "Priority: 2" \
                -H "Tags: backup,restic,$config_name,success" \
                -d "$message" \
                "https://ntfy.sh/$ntfy_topic"
        else
            # Repository check failed
            message="❌ Repository integrity check failed!

📦 Snapshot ${snapshot_id} was created successfully
⏱️ Duration: $(format_duration $backup_duration)
📊 Files: $total_files_processed processed
💾 Size: $(format_bytes $data_added) added

⚠️ The $check_description integrity check failed. Please investigate!"

            curl -s \
                -H "Title: ⚠️ Restic Backup Warning - $config_name" \
                -H "Priority: 5" \
                -H "Tags: backup,restic,$config_name,warning" \
                -d "$message" \
                "https://ntfy.sh/$ntfy_topic"
        fi
    fi

    if [ "$backup_success" = false ]; then
        exit 1
    fi

else
    # Backup failed
    backup_end_time=$(date +%s)
    backup_duration=$((backup_end_time - backup_start_time))

    # Extract error message
    error_message=$(cat "$error_log" 2>/dev/null | head -20)
    if [ -z "$error_message" ]; then
        error_message="Unknown error occurred during backup"
    fi

    # Save error log locally
    local_log_file="$log_dir/restic_error_${config_name}_$(date +%Y%m%d_%H%M%S).log"
    {
        echo "=== BACKUP ERROR LOG ==="
        echo "Config: $config_file"
        echo "Repository: $repo_path"
        echo "Start time: $(date -d @$backup_start_time)"
        echo "Duration: $(format_duration $backup_duration)"
        echo ""
        echo "=== ERROR OUTPUT ==="
        cat "$error_log" 2>/dev/null || echo "No error output captured"
        echo ""
        echo "=== BACKUP OUTPUT ==="
        cat "$backup_output" 2>/dev/null || echo "No backup output captured"
    } > "$local_log_file"
    echo "Error log saved to: $local_log_file"

    if [ -n "${ntfy_topic:-}" ]; then
        # Send error notification with log file attached
        filename="backup_error_${config_name}_$(date +%Y%m%d_%H%M%S).log"
        curl -s \
            -T "$local_log_file" \
            -H "Filename: $filename" \
            -H "Title: ❌ Restic Backup Failed - $config_name" \
            -H "Priority: 5" \
            -H "Tags: backup,restic,$config_name,error" \
            "https://ntfy.sh/$ntfy_topic"

        # Give ntfy time to process the attachment
        sleep 2
    fi

    exit 1
fi
