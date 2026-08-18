#!/usr/bin/env bash
# Backup jarvis VPS workspace via SSHFS mount + restic.
# Mounts the docker volume from jarvis, runs restic_backup.sh, unmounts.
#
# Usage: jarvis_backup.sh <restic_config_file>
#   e.g.: jarvis_backup.sh ~/.dotfiles/secrets/backup/restic/jarvis/rsyncnet.conf

set -euo pipefail

MOUNTPOINT="/tmp/jarvis-backup"
REMOTE="root@jarvis:/var/lib/docker/volumes/jarvis_jarvis-workspace/_data"
SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"

config_file="${1:-}"
if [ -z "$config_file" ] || [ ! -f "$config_file" ]; then
    echo "Usage: $0 <config_file>" >&2
    exit 1
fi

# Lazy unmount, and no mountpoint test first: both stat the mount, and a stat on
# a mount whose sshfs is gone blocks in the kernel with no timeout. -z detaches
# the mount from the tree without waiting, so this always returns and the next
# run always finds a clear path. It does not free a process already stuck reading
# the mount; only the sshfs process exiting does that.
cleanup() {
    fusermount -uz "$MOUNTPOINT" 2>/dev/null || fusermount3 -uz "$MOUNTPOINT" 2>/dev/null || true
}
trap cleanup EXIT

mkdir -p "$MOUNTPOINT"

if mountpoint -q "$MOUNTPOINT" 2>/dev/null; then
    echo "[jarvis-backup] Already mounted at $MOUNTPOINT"
else
    echo "[jarvis-backup] Mounting $REMOTE → $MOUNTPOINT"
    # jarvis away is a skip, like every other unreachable target; if it keeps
    # failing, the repo's snapshots go stale and the watchdog says so. The unit
    # name matches the one restic_backup.sh logs under, so it is one series.
    if ! mount_error=$(sshfs -o ro "$REMOTE" "$MOUNTPOINT" 2>&1); then
        config_name="$(basename "$(dirname "$config_file")")-$(basename "$config_file" .conf)"
        echo "[jarvis-backup] Could not mount $REMOTE: $mount_error" >&2
        # Whatever went wrong, sshfs signs off with the same "read: Connection
        # reset by peer"; the line worth recording is what ssh said before it.
        reason=$("$SCRIPT_DIR/../bin/unreachable-reason" <<<"$mount_error") \
            || reason=$(head -1 <<<"$mount_error")
        "$SCRIPT_DIR/../bin/run-log" "$config_name" skip \
            --reason "sshfs mount failed: ${reason:-no output from sshfs}" || true
        exit 0
    fi
fi

echo "[jarvis-backup] Running restic backup"
"$SCRIPT_DIR/restic_backup.sh" "$config_file"
