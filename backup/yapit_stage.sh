#!/usr/bin/env bash
# Runs on yapit-prod (fed over ssh by sshfs_backup.sh): writes consistent copies
# of the live databases to /opt/yapit/backup/current, which the restic run then
# reads over the SSHFS mount. Copying the live files instead would catch
# Postgres and SQLite mid-write.
#
# - Postgres (app DB, metrics DB): pg_dump custom format, made inside each
#   container so the client matches the server. Restore with pg_restore; the
#   metrics DB is TimescaleDB and needs timescaledb_pre_restore() first.
# - SQLite caches: the online backup API, which copies a consistent state
#   while the gateway keeps writing. The audio cache is left out: it refills
#   itself from synthesis, and it is the bulk of the disk.
#
# The new set is staged beside the old one and swapped in only once complete,
# so a failed run leaves the previous set in place and exits non-zero.

set -euo pipefail

out=/opt/yapit/backup
volumes=/var/lib/docker/volumes
mkdir -p "$out"
rm -rf "$out"/.staging.*
staging=$(mktemp -d "$out/.staging.XXXXXX")

pg_dump_service() {
    local service=$1 container
    container=$(docker ps -q --filter "name=^yapit_${service}\." | head -1)
    [ -n "$container" ] || { echo "no running container for yapit_$service" >&2; exit 1; }
    docker exec "$container" sh -c 'pg_dump -Fc -U "$POSTGRES_USER" "$POSTGRES_DB"' >"$staging/$service.pgdump"
}

sqlite_copy() {
    local src=$1 name=$2
    sqlite3 "$src" ".backup '$staging/$name'"
}

pg_dump_service postgres
pg_dump_service metrics-db
sqlite_copy "$volumes/yapit_document_cache/_data/cache.db" document_cache.db
sqlite_copy "$volumes/yapit_extraction_cache/_data/cache.db" extraction_cache.db

rm -rf "$out/current"
mv "$staging" "$out/current"
du -sh "$out/current"/*
