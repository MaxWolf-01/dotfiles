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

config_name="$("$SCRIPT_DIR/../bin/restic-config-name" "$config_file")"

log_run() {
    "$SCRIPT_DIR/../bin/run-log" "$config_name" "$@" || true
}

# Asked before the mount, because the mount cannot answer it: an empty agent is
# one of the causes that reach us as an indistinguishable "Connection reset by
# peer" (see the mount below). An empty agent is the ordinary state after a boot
# and skips like any other missing precondition. No agent at all is a broken
# session; the alert for that comes from this host's sftp repos, which meet the
# same condition in restic_backup.sh, so it is not raised twice here.
agent_state=0
ssh-add -l >/dev/null 2>&1 || agent_state=$?
if [ "$agent_state" -eq 1 ]; then
    echo "[jarvis-backup] Skipping: the ssh agent holds no key"
    log_run skip --reason "ssh agent holds no key"
    exit 0
fi
if [ "$agent_state" -eq 2 ]; then
    echo "[jarvis-backup] No ssh agent answered at ${SSH_AUTH_SOCK:-<unset>}" >&2
    log_run fail --reason "no ssh agent at ${SSH_AUTH_SOCK:-<unset>}"
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
    # jarvis away is a skip, like every other unreachable target; a mount that
    # keeps failing surfaces as the repo's snapshots going stale. The unit name
    # matches the one restic_backup.sh logs under, so it is one series.
    #
    # Why the cause is not in the reason: without -f, sshfs sends its ssh
    # child's stderr to /dev/null, so a dead host, a rejected key and a changed
    # host key all read "read: Connection reset by peer" and nothing else.
    #
    # no_contain_symlinks: sshfs otherwise fails readlink with EPERM for any
    # target that is absolute or contains "..", and restic stores such a symlink
    # with an empty target. Every symlink in this tree is one of those, and all
    # of them are correct — knowledge-base/library resolves on the laptop the
    # vault is checked out on, .xdg/bin/* inside the container. Containment
    # protects a client that follows a hostile server's link into local files;
    # restic records the target string and never follows it.
    if ! mount_error=$(sshfs -o ro,no_contain_symlinks "$REMOTE" "$MOUNTPOINT" 2>&1); then
        echo "[jarvis-backup] Could not mount $REMOTE: $mount_error" >&2
        reason=$(head -1 <<<"$mount_error")
        log_run skip --reason "sshfs mount failed: ${reason:-no output from sshfs}"
        exit 0
    fi
fi

echo "[jarvis-backup] Running restic backup"
"$SCRIPT_DIR/restic_backup.sh" "$config_file"
