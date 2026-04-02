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

cleanup() {
    if mountpoint -q "$MOUNTPOINT" 2>/dev/null; then
        fusermount -u "$MOUNTPOINT" 2>/dev/null || fusermount3 -u "$MOUNTPOINT" 2>/dev/null || true
    fi
}
trap cleanup EXIT

mkdir -p "$MOUNTPOINT"

if mountpoint -q "$MOUNTPOINT" 2>/dev/null; then
    echo "[jarvis-backup] Already mounted at $MOUNTPOINT"
else
    echo "[jarvis-backup] Mounting $REMOTE → $MOUNTPOINT"
    sshfs -o ro "$REMOTE" "$MOUNTPOINT"
fi

echo "[jarvis-backup] Running restic backup"
"$SCRIPT_DIR/restic_backup.sh" "$config_file"
