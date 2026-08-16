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
#
# Written via a temp file: the API answers auth failures with a JSON error body
# and a non-zero exit, so a direct redirect would leave that error staged as if
# it were the dump.
sftpgo_stage="$stage/sftpgo"
mkdir -p "$sftpgo_stage"
chmod 700 "$sftpgo_stage"
(umask 077; "$HOME/.dotfiles/bin/sftpgo-user" dump > "$sftpgo_stage/.sftpgo-backup.json.tmp")
mv "$sftpgo_stage/.sftpgo-backup.json.tmp" "$sftpgo_stage/sftpgo-backup.json"

# --- mdsr (spaced repetition) ---------------------------------------------
# The service is retired but its review history is not: keep copying the DB
# until skilltree has taken the data over. Absent is fine — that is the state
# after the handover — so this block does not fail the run.
#
# Live SQLite in WAL mode: a raw cp of the .db would miss reviews still in the
# -wal file (and could capture a torn state). The online backup API writes a
# single consistent file even under concurrent writes.
mdsr_stage="$stage/mdsr"
shopt -s nullglob
mdsr_dbs=("$HOME/.local/share/mdsr"/*.db)
rm -rf "$mdsr_stage"
mkdir -p "$mdsr_stage"
for db in "${mdsr_dbs[@]}"; do
    sqlite3 "$db" ".backup '$mdsr_stage/$(basename "$db")'"
done
