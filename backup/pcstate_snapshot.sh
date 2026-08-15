#!/usr/bin/env bash
# Stage consistent snapshots of pc-local service state for backup.
#
# pc runs services whose state lives on its own disk (not in any tank dataset),
# so it isn't covered by the dataset-oriented repos. This collects that state
# into a staging tree which the `pcstate` restic config backs up to rsync.net.
#
# Adding a service = add a block below that writes into "$stage/<service>/" and
# a matching line in secrets/backup/restic/pcstate/dirs.txt.

set -euo pipefail

# Must match base_path in secrets/backup/restic/pcstate/_common.
stage="${1:-$HOME/.local/state/pcstate}"

# --- sftpgo (file drop) ----------------------------------------------------
# Accounts, quotas, shares and event rules — none of it reproducible from the
# Nix config. SFTPGo's own dump is the right unit: it is exactly what `loaddata`
# restores, and taking it over the API avoids reading the service's SQLite (root
# owned, and live). The dump carries password hashes, so keep it 0600; the
# restic repo it lands in is encrypted.
#
# Dropped files themselves are not staged: they expire after 9 months by design.
sftpgo_stage="$stage/sftpgo"
rm -rf "$sftpgo_stage"
mkdir -p "$sftpgo_stage"
chmod 700 "$sftpgo_stage"
umask 077
"$HOME/.dotfiles/bin/sftpgo-user" dump > "$sftpgo_stage/sftpgo-backup.json"
