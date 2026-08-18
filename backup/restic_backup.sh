#!/usr/bin/env bash
# Restic backup wrapper. Every run appends its outcome and stats to the run log
# (bin/run-log); ntfy is reserved for the failures a person has to act on, which
# is every failure this script can name. A green run and a deliberate skip —
# dataset unmounted, age key still encrypted — are silent.

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
# require_mount - (optional) Path that must be a mountpoint, else skip (for encrypted ZFS datasets)

# Reached relative to this script, not through PATH: the systemd units pin
# their own PATH and none of them carries ~/bin.
run_log_bin="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../bin/run-log"

# Recording the run must never decide whether the backup succeeded: run-log
# explains itself on stderr and the backup carries on.
log_run() {
    "$run_log_bin" "$config_name" "$@" || true
}

# A failure that needs a human: notify, record, stop. $1 is the one-line reason
# for the run log, $2 the full text for the notification.
fail_out() {
    local reason="$1"
    local detail="$2"

    log_run fail --reason "$reason"
    if [ -n "${ntfy_topic:-}" ]; then
        curl -s \
            -H "Title: ❌ $config_name - Backup Failed" \
            -H "Priority: 5" \
            -H "Tags: backup,restic,$config_name,error" \
            -d "$detail" \
            "https://ntfy.sh/$ntfy_topic"
    fi
    echo "$detail" >&2
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

# Validate required variables before using them (set -u would exit silently otherwise)
required_vars="repo_path password_command backup_dirs_file base_path compression keep_last keep_daily keep_weekly keep_monthly"
missing_vars=""
for var in $required_vars; do
    if [ -z "${!var:-}" ]; then
        missing_vars="$missing_vars $var"
    fi
done
if [ -n "$missing_vars" ]; then
    fail_out "missing config variables:$missing_vars" \
        "Missing required config variables:$missing_vars"
fi

# Optional: abort if a required mountpoint isn't mounted (e.g., encrypted ZFS datasets)
# Prevents creating empty snapshots that could push out real data via retention.
if [ -n "${require_mount:-}" ]; then
    if ! mountpoint -q "$require_mount"; then
        echo "Skipping $config_name: $require_mount is not mounted"
        log_run skip --reason "$require_mount is not mounted"
        exit 0
    fi
fi

# Abort if age key is not available (encrypted at rest, not yet decrypted)
age_key="${SOPS_AGE_KEY_FILE:-$HOME/.local/secrets/age-key.txt}"
if [ ! -f "$age_key" ]; then
    echo "Skipping $config_name: age key not available at $age_key (decrypt it first)"
    log_run skip --reason "age key not decrypted at $age_key"
    exit 0
fi

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
        fail_out "could not initialise repository at $repo_path" \
            "Failed to initialize restic repository at $repo_path

ERROR OUTPUT:
$error_details

Logs: $repo_check_log, $init_log
Config: $config_file
Repo: $repo_path
Password command: $password_command"
    fi
fi

# Remove stale locks (>30min unrefreshed or dead PID on same host)
restic --repo "$repo_path" --password-command "$password_command" unlock 2>/dev/null

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

sed "s|^|$base_path/|" "$backup_dirs_file" | \
   restic --repo "$repo_path" backup \
    --option compression="$compression" \
    --files-from-verbatim - \
    --password-command "$password_command" \
    $exclude_opts \
    $scan_option \
    --json 2>"$error_log" | tee "$backup_output"
backup_exit=${PIPESTATUS[1]}

# 0 = clean, 3 = snapshot created but some files unreadable (e.g. race with
# ephemeral files). Real failures are exit 1/2.
if [ "$backup_exit" -eq 0 ] || [ "$backup_exit" -eq 3 ]; then
    had_warnings=$([ "$backup_exit" -eq 3 ] && echo true || echo false)
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

    # Run forget and prune
    echo "Pruning old snapshots..."
    restic --repo "$repo_path" forget --prune \
        --keep-last "$keep_last" \
        --keep-daily "$keep_daily" \
        --keep-weekly "$keep_weekly" \
        --keep-monthly "$keep_monthly" \
        --password-command "$password_command" >/dev/null 2>&1

    # The repository's own size, after this run's prune: what the backup costs at
    # rest, deduplicated and compressed. Nothing in the backup summary implies it
    # — that measures the source tree — and reading it walks the whole index,
    # which is ~15s on a 140 GB repo over sftp. Paid once per run here so that
    # every reader afterwards, the dashboard included, gets it for free.
    repo_size=null
    repo_snapshots=null
    if repo_stats=$(restic --repo "$repo_path" --password-command "$password_command" \
            stats --mode raw-data --no-lock --json 2>/dev/null); then
        repo_size=$(jq -r '.total_size // empty' <<<"$repo_stats")
        repo_snapshots=$(jq -r '.snapshots_count // empty' <<<"$repo_stats")
    fi
    # A size that could not be read must leave the field out, never guess at it.
    [[ "$repo_size" =~ ^[0-9]+$ ]] || repo_size=null
    [[ "$repo_snapshots" =~ ^[0-9]+$ ]] || repo_snapshots=null
    if [ "$repo_size" = null ]; then
        echo "Could not read repository size (the backup itself is unaffected)" >&2
    fi

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

    # Remove stale locks before check (prune may leave one if interrupted)
    restic --repo "$repo_path" --password-command "$password_command" unlock 2>/dev/null

    # Run repository check
    echo "Checking repository integrity..."
    if check_error_msg=$(restic check --repo "$repo_path" --password-command "$password_command" $check_args 2>&1 >/dev/null); then
        check_status="passed"
    else
        check_status="FAILED"
        backup_success=false
    fi

    # Unreadable files are reported as JSON error lines, but other exit-3 causes
    # (a missing source dir) only show up as plain stderr — so this count can be
    # zero while the run still had warnings. Whoever reads `warnings` has to be
    # able to reach the text, hence the path alongside it.
    warn_count=0
    warning_log=""
    if [ "$had_warnings" = true ]; then
        warn_count=$(grep -c '"message_type":"error"' "$error_log" || true)
        warning_log="$log_dir/restic_warning_${config_name}_$(date +%Y%m%d_%H%M%S).log"
        cat "$error_log" > "$warning_log"
        echo "Warning log saved to: $warning_log"
    fi

    # $ARGS.named collects every --arg/--argjson above into one object, so each
    # field is named once instead of twice.
    stats=$(jq -n \
        --arg snapshot_id "$snapshot_id" \
        --arg check "${check_status,,}" \
        --arg check_scope "$check_description" \
        --argjson duration_s "$backup_duration" \
        --argjson total_files_processed "$total_files_processed" \
        --argjson files_new "$files_new" \
        --argjson files_changed "$files_changed" \
        --argjson files_unmodified "$files_unmodified" \
        --argjson total_bytes_processed "$total_bytes_processed" \
        --argjson data_added "$data_added" \
        --argjson data_added_packed "$data_added_packed" \
        --argjson repo_size "$repo_size" \
        --argjson repo_snapshots "$repo_snapshots" \
        --argjson warnings "$warn_count" \
        --arg warning_log "$warning_log" \
        '$ARGS.named
         | if .warning_log == "" then del(.warning_log) else . end
         | if .repo_size == null then del(.repo_size, .repo_snapshots) else . end')

    if [ "$backup_success" = true ]; then
        log_run ok --stats "$stats"
    else
        log_run fail --reason "$check_description integrity check failed" --stats "$stats"

        if [ -n "${ntfy_topic:-}" ]; then
            message="❌ Repository integrity check failed!

📦 Snapshot ${snapshot_id} was created successfully
⏱️ Duration: $(format_duration $backup_duration)
📊 Files: $total_files_processed processed
💾 Size: $(format_bytes $data_added) added

⚠️ The $check_description integrity check failed:
${check_error_msg}"

            curl -s \
                -H "Title: ⚠️ $config_name - Integrity Check Failed" \
                -H "Priority: 5" \
                -H "Tags: backup,restic,$config_name,warning" \
                -d "$message" \
                "https://ntfy.sh/$ntfy_topic"
        fi
    fi

    if [ "$backup_success" = false ]; then
        exit 1
    fi
    exit 0

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

    log_run fail \
        --reason "restic backup exited $backup_exit: $(head -1 <<<"$error_message")" \
        --stats "$(jq -n --argjson duration_s "$backup_duration" \
                        --argjson exit_code "$backup_exit" \
                        --arg error_log "$local_log_file" '$ARGS.named')"

    if [ -n "${ntfy_topic:-}" ]; then
        # Send error notification with log file attached
        filename="backup_error_${config_name}_$(date +%Y%m%d_%H%M%S).log"
        curl -s \
            -T "$local_log_file" \
            -H "Filename: $filename" \
            -H "Title: ❌ $config_name - Backup Failed" \
            -H "Priority: 5" \
            -H "Tags: backup,restic,$config_name,error" \
            "https://ntfy.sh/$ntfy_topic"

        # Give ntfy time to process the attachment
        sleep 2
    fi

    exit 1
fi
