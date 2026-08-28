#!/usr/bin/env bash
# Sync phone data to PC via rsync over Tailscale SSH.
# Runs as a systemd timer or manually. Requires:
#   - Tailscale running on both PC and phone
#   - rsync installed on phone (pkg install rsync in Termux)
#   - ZFS dataset tank/max/phone mounted at /home/max/data/phone
#
# Sends no notifications: an away phone or an unsynced photo is nothing to act
# on right now. Each run appends its outcome to the run log instead.

set -uo pipefail

PHONE_HOST="phone"
DEST="/home/max/data/phone"

# Reached relative to this script, not through PATH: the systemd unit pins its
# own PATH and it does not carry ~/bin.
run_log_bin="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../bin/run-log"

# Recording the run must never decide whether the sync succeeded: run-log
# explains itself on stderr and the sync carries on.
log_run() {
    "$run_log_bin" phone-sync "$@" || true
}

# The phone drops the connection on long transfers (screen off, Android
# suspending Termux, mobile link). Each attempt resumes from the partial dir,
# so a big catch-up gets there across several tries instead of failing outright.
MAX_ATTEMPTS=4
RETRY_WAIT=30
IO_TIMEOUT=180

# Directories to sync: phone_path → local_subdir
#
# WhatsApp keeps its media under Android/media/, outside the shared picture and
# document trees, so nothing above reaches it. The whole Media directory is one
# entry rather than a list of its subdirectories: WhatsApp adds new media types
# over time and they should land here without anyone editing this map.
declare -A DIRS=(
    ["~/storage/dcim"]="DCIM"
    ["~/storage/pictures"]="Pictures"
    ["~/storage/downloads"]="Download"
    ["~/storage/shared/Documents"]="Documents"
    ["~/storage/shared/Recordings"]="Recordings"
    ["~/storage/shared/Android/media/com.whatsapp/WhatsApp/Media"]="WhatsApp"
)

# Pre-flight: ZFS dataset must be mounted
if ! mountpoint -q "$DEST"; then
    echo "Skipping phone sync: $DEST is not mounted"
    log_run skip --reason "$DEST is not mounted"
    exit 0
fi

# Pre-flight: the key the phone is reached with. Without this the check below
# fails on publickey and records an away phone, which is a cause that was never
# true and one a reader of the run log cannot tell from the real thing.
agent_state=0
ssh-add -l >/dev/null 2>&1 || agent_state=$?
if [ "$agent_state" -ne 0 ]; then
    echo "Skipping phone sync: the ssh agent holds no key"
    log_run skip --reason "ssh agent holds no key"
    exit 0
fi

# Pre-flight: phone must be reachable
if ! ssh -o ConnectTimeout=10 "$PHONE_HOST" true 2>/dev/null; then
    echo "Skipping phone sync: $PHONE_HOST is not reachable"
    log_run skip --reason "$PHONE_HOST is not reachable"
    exit 0
fi

log_dir="$HOME/logs/phone-sync"
mkdir -p "$log_dir"
log_file="$log_dir/sync_$(date +%Y%m%d_%H%M%S).log"

echo "=== Phone Sync - $(date) ===" | tee "$log_file"

failed_dirs=()
total_transferred=0

# Socket I/O (10), protocol stream (12), I/O timeout (30) and ssh dying (255)
# are the ways a dropped link surfaces. Any other code is a real error that
# another attempt won't fix.
is_retryable() {
    case "$1" in
        10 | 12 | 30 | 255) return 0 ;;
        *) return 1 ;;
    esac
}

for phone_path in "${!DIRS[@]}"; do
    local_dir="$DEST/${DIRS[$phone_path]}"
    mkdir -p "$local_dir"

    echo "Syncing $phone_path → $local_dir" | tee -a "$log_file"

    attempt=1
    count=0
    while true; do
        # --partial-dir, not --partial: an interrupted file stays in
        # .rsync-partial instead of sitting at its real path truncated, where
        # the restic run that follows would snapshot it as if it were complete.
        output=$(rsync -az --partial-dir=.rsync-partial --timeout="$IO_TIMEOUT" \
            --itemize-changes \
            --exclude='.thumbnails' \
            --exclude='.nomedia' \
            "$PHONE_HOST:$phone_path/" "$local_dir/" 2>&1)
        rc=$?

        echo "$output" >> "$log_file"
        # --itemize-changes: ">f" = received file, ">L" = received symlink
        count=$((count + $(echo "$output" | grep -c '^>f' || true)))

        [ $rc -eq 0 ] && break
        is_retryable "$rc" || break
        [ "$attempt" -ge "$MAX_ATTEMPTS" ] && break

        echo "  attempt $attempt failed (exit $rc), retrying in ${RETRY_WAIT}s" | tee -a "$log_file"
        attempt=$((attempt + 1))
        sleep "$RETRY_WAIT"
    done

    if [ $rc -ne 0 ]; then
        echo "  FAILED (exit $rc after $attempt attempt(s))" | tee -a "$log_file"
        failed_dirs+=("${DIRS[$phone_path]}")
    else
        echo "  OK ($count new files, $attempt attempt(s))" | tee -a "$log_file"
        total_transferred=$((total_transferred + count))
    fi
done

echo "" | tee -a "$log_file"
echo "=== Summary ===" | tee -a "$log_file"
echo "Log: $log_file" | tee -a "$log_file"

stats=$(jq -n --argjson files_synced "$total_transferred" \
              --arg log "$log_file" \
              --args '$ARGS.named + {dirs_failed: $ARGS.positional}' \
              -- "${failed_dirs[@]}")

if [ ${#failed_dirs[@]} -eq 0 ]; then
    log_run ok --stats "$stats"
    exit 0
fi

failed_list=$(IFS=,; echo "${failed_dirs[*]}")
echo "Failed: $failed_list" | tee -a "$log_file"
log_run fail --reason "rsync failed for: $failed_list" --stats "$stats"
exit 1
