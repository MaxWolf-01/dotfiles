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

# --- mdsr (spaced repetition) ---------------------------------------------
# Live SQLite in WAL mode: a raw cp of the .db would miss reviews still in the
# -wal file (and could capture a torn state). The online backup API writes a
# single consistent file even under concurrent writes.
mdsr_stage="$stage/mdsr"
shopt -s nullglob
mdsr_dbs=("$HOME/.local/share/mdsr"/*.db)
if (( ${#mdsr_dbs[@]} == 0 )); then
    echo "pcstate_snapshot: no mdsr DB under ~/.local/share/mdsr — is mdsr deployed here?" >&2
    exit 1
fi
rm -rf "$mdsr_stage"
mkdir -p "$mdsr_stage"
for db in "${mdsr_dbs[@]}"; do
    sqlite3 "$db" ".backup '$mdsr_stage/$(basename "$db")'"
done
