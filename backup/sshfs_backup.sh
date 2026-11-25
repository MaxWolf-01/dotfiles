#!/usr/bin/env bash
# Back up a remote host over an SSHFS mount + restic.
# Optionally runs the config's stage_script on the remote host first (over ssh,
# fed on stdin), mounts the config's sshfs_remote read-only at its base_path,
# runs restic_backup.sh, unmounts.
#
# Usage: sshfs_backup.sh <restic_config_file>
#   e.g.: sshfs_backup.sh ~/.dotfiles/secrets/backup/restic/jarvis/rsyncnet.conf
#
# Config variables on top of restic_backup.sh's:
# sshfs_remote - user@host:/path to mount
# stage_script - (optional) local script to run on that host before the mount,
#                e.g. to dump databases into a directory the mount covers

set -euo pipefail

SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"

config_file="${1:-}"
if [ -z "$config_file" ] || [ ! -f "$config_file" ]; then
    echo "Usage: $0 <config_file>" >&2
    exit 1
fi

config_name="$("$SCRIPT_DIR/../bin/restic-config-name" "$config_file")"
MOUNTPOINT="$(source "$config_file" && echo "$base_path")"
REMOTE="$(source "$config_file" && echo "${sshfs_remote:?$config_file sets no sshfs_remote}")"
STAGE_SCRIPT="$(source "$config_file" && echo "${stage_script:-}")"
REMOTE_HOST="${REMOTE%%:*}"
TAG="[$config_name]"

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
    echo "$TAG Skipping: the ssh agent holds no key"
    log_run skip --reason "ssh agent holds no key"
    exit 0
fi
if [ "$agent_state" -eq 2 ]; then
    echo "$TAG No ssh agent answered at ${SSH_AUTH_SOCK:-<unset>}" >&2
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

if [ -n "$STAGE_SCRIPT" ]; then
    echo "$TAG Staging on $REMOTE_HOST with $STAGE_SCRIPT"
    # ssh exits 255 when it cannot reach the host: a skip, like a failed mount.
    # Any other non-zero exit is the stage script's own failure, and snapshotting
    # yesterday's staged files as if they were today's would hide it.
    stage_exit=0
    stage_output=$(ssh -o BatchMode=yes -o ConnectTimeout=30 "$REMOTE_HOST" bash -s <"$STAGE_SCRIPT" 2>&1) || stage_exit=$?
    echo "$stage_output"
    if [ "$stage_exit" -eq 255 ]; then
        log_run skip --reason "ssh to $REMOTE_HOST failed: $(tail -1 <<<"$stage_output")"
        exit 0
    fi
    if [ "$stage_exit" -ne 0 ]; then
        log_run fail --reason "stage script exited $stage_exit"
        "$SCRIPT_DIR/../bin/alert-send" "❌ $config_name - Backup Failed" <<EOF || true
The stage script $STAGE_SCRIPT exited $stage_exit on $REMOTE_HOST, so nothing
was backed up. Its output:

$stage_output
EOF
        exit 1
    fi
fi

mkdir -p "$MOUNTPOINT"

if mountpoint -q "$MOUNTPOINT" 2>/dev/null; then
    echo "$TAG Already mounted at $MOUNTPOINT"
else
    echo "$TAG Mounting $REMOTE → $MOUNTPOINT"
    # The host away is a skip, like every other unreachable target; a mount that
    # keeps failing surfaces as the repo's snapshots going stale. The unit name
    # matches the one restic_backup.sh logs under, so it is one series.
    #
    # Why the cause is not in the reason: without -f, sshfs sends its ssh
    # child's stderr to /dev/null, so a dead host, a rejected key and a changed
    # host key all read "read: Connection reset by peer" and nothing else.
    #
    # no_contain_symlinks: sshfs otherwise fails readlink with EPERM for any
    # target that is absolute or contains "..", and restic stores such a symlink
    # with an empty target. In the jarvis workspace every symlink is one of
    # those, and all of them are correct — knowledge-base/library resolves on
    # the laptop the vault is checked out on, .xdg/bin/* inside the container. Containment
    # protects a client that follows a hostile server's link into local files;
    # restic records the target string and never follows it.
    if ! mount_error=$(sshfs -o ro,no_contain_symlinks "$REMOTE" "$MOUNTPOINT" 2>&1); then
        echo "$TAG Could not mount $REMOTE: $mount_error" >&2
        reason=$(head -1 <<<"$mount_error")
        log_run skip --reason "sshfs mount failed: ${reason:-no output from sshfs}"
        exit 0
    fi
fi

echo "$TAG Running restic backup"
require_mount="$MOUNTPOINT" "$SCRIPT_DIR/restic_backup.sh" "$config_file"
