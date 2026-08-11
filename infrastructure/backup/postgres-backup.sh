#!/bin/sh
set -eu
. "$(dirname "$0")/../scripts/common.sh"

require_service postgres
timestamp=$(date -u +%Y%m%dT%H%M%SZ)
archive="$BACKUP_DIR/postgres-${PROJECT_NAME}-${timestamp}.dump"
trap 'rm -f "$archive" "$archive.sha256"' EXIT HUP INT TERM

compose exec -T postgres pg_dump \
    --username "$POSTGRES_USER" \
    --dbname "$POSTGRES_DB" \
    --format custom > "$archive"
checksum_create "$archive"
trap - EXIT HUP INT TERM
printf '%s\n' "$archive"

