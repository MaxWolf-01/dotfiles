#!/bin/bash
# Sync phone data to PC via rsync over Tailscale SSH.
# Runs as a systemd timer or manually. Requires:
#   - Tailscale running on both PC and phone
#   - rsync installed on phone (pkg install rsync in Termux)
#   - ZFS dataset tank/max/phone mounted at /home/max/data/phone

set -uo pipefail

PHONE_HOST="phone"
DEST="/home/max/data/phone"
NTFY_TOPIC="${NTFY_TOPIC:-}"

# Directories to sync: phone_path → local_subdir
declare -A DIRS=(
    ["~/storage/dcim"]="DCIM"
    ["~/storage/pictures"]="Pictures"
    ["~/storage/downloads"]="Download"
    ["~/storage/shared/Documents"]="Documents"
    ["~/storage/shared/Recordings"]="Recordings"
)

# Pre-flight: ZFS dataset must be mounted
if ! mountpoint -q "$DEST"; then
    echo "Skipping phone sync: $DEST is not mounted"
    exit 0
fi

# Pre-flight: phone must be reachable
if ! ssh -o ConnectTimeout=10 "$PHONE_HOST" true 2>/dev/null; then
    echo "Skipping phone sync: $PHONE_HOST is not reachable"
    exit 0
fi

log_dir="$HOME/logs/phone-sync"
mkdir -p "$log_dir"
log_file="$log_dir/sync_$(date +%Y%m%d_%H%M%S).log"

echo "=== Phone Sync - $(date) ===" | tee "$log_file"

failed=""
total_transferred=0

for phone_path in "${!DIRS[@]}"; do
    local_dir="$DEST/${DIRS[$phone_path]}"
    mkdir -p "$local_dir"

    echo "Syncing $phone_path → $local_dir" | tee -a "$log_file"

    output=$(rsync -az --partial --itemize-changes \
        --exclude='.thumbnails' \
        --exclude='.nomedia' \
        "$PHONE_HOST:$phone_path/" "$local_dir/" 2>&1)
    rc=$?

    echo "$output" >> "$log_file"

    if [ $rc -ne 0 ]; then
        echo "  FAILED (exit $rc)" | tee -a "$log_file"
        failed="${failed}${DIRS[$phone_path]}, "
    else
        # --itemize-changes: ">f" = received file, ">L" = received symlink
        count=$(echo "$output" | grep -c '^>f' || true)
        echo "  OK ($count new files)" | tee -a "$log_file"
        total_transferred=$((total_transferred + count))
    fi
done

echo "" | tee -a "$log_file"
echo "=== Summary ===" | tee -a "$log_file"
echo "Log: $log_file" | tee -a "$log_file"

if [ -n "$failed" ]; then
    echo "Failed: ${failed%, }" | tee -a "$log_file"
fi

# Notification
if [ -n "$NTFY_TOPIC" ]; then
    if [ -n "$failed" ]; then
        curl -s -H "Title: Phone Sync - Failures" -H "Priority: 4" -H "Tags: phone,warning" \
            -d "Failed: ${failed%, }" "https://ntfy.sh/$NTFY_TOPIC"
    elif [ $total_transferred -gt 0 ]; then
        curl -s -H "Title: Phone Sync" -H "Priority: 2" -H "Tags: phone,success" \
            -d "Synced $total_transferred new files" "https://ntfy.sh/$NTFY_TOPIC"
    fi
fi

[ -z "$failed" ] || exit 1
