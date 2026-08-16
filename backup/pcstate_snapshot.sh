#!/usr/bin/env bash
# Stage consistent snapshots of pc-local service state for backup.
#
# pc runs services whose state lives on its own disk (not in any tank dataset),
# so it isn't covered by the dataset-oriented repos. This collects that state
# into a staging tree which the `pcstate` restic config backs up to rsync.net.
#
# Adding a service = add a block below that writes into "$stage/<service>/" and
# a matching line in secrets/backup/restic/pcstate/dirs.txt. Order the blocks so
# irreplaceable state is staged first: a later block that fails must not be able
# to hold an earlier one out of the backup.

set -euo pipefail

# Must match base_path in secrets/backup/restic/pcstate/_common.
stage="${1:-$HOME/.local/state/pcstate}"

# The sftpgo dump needs an API key that sops decrypts, so this needs the age key
# just like restic_backup.sh does. Skip rather than fail: on pc the key lives on
# tmpfs and is absent until the first interactive login after a reboot, and a
# failed ExecStartPre would mark the unit failed on every such boot.
age_key="${SOPS_AGE_KEY_FILE:-$HOME/.local/secrets/age-key.txt}"
if [ ! -f "$age_key" ]; then
    echo "pcstate_snapshot: age key not available at $age_key — skipping (decrypt it first)"
    exit 0
fi

# --- mdsr (spaced repetition) ---------------------------------------------
# The service is retired; this DB is the only copy of the review history until
# skilltree takes the data over. Staged first, and before anything that depends
# on the network.
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

# --- sftpgo (file drop) ----------------------------------------------------
# Accounts, quotas, shares and event rules — none of it reproducible from the
# Nix config. SFTPGo's own dump is the right unit: it is exactly what `loaddata`
# restores, and taking it over the API avoids reading the service's SQLite (root
# owned, and live). The dump carries password hashes, so keep it 0600; the
# restic repo it lands in is encrypted.
#
# Dropped files themselves are not staged: they expire after 9 months by design.
#
# A rotated key or an unreachable API must not cost the run: the dump is written
# to a temp file and only replaces the previous one on success, and a failure
# removes the stale copy so the backup records the gap rather than a dump that
# quietly stopped tracking reality.
sftpgo_stage="$stage/sftpgo"
mkdir -p "$sftpgo_stage"
chmod 700 "$sftpgo_stage"
if (umask 077; "$HOME/.dotfiles/bin/sftpgo-user" dump > "$sftpgo_stage/.sftpgo-backup.json.tmp"); then
    mv "$sftpgo_stage/.sftpgo-backup.json.tmp" "$sftpgo_stage/sftpgo-backup.json"
else
    rm -f "$sftpgo_stage/.sftpgo-backup.json.tmp" "$sftpgo_stage/sftpgo-backup.json"
    echo "pcstate_snapshot: sftpgo dump failed — accounts are NOT in this backup" >&2
fi
