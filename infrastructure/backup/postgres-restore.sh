#!/bin/sh
set -eu
. "$(dirname "$0")/../scripts/common.sh"

archive=${1:?Usage: postgres-restore.sh <archive.dump>}
test -f "$archive" || { echo "Archive not found: $archive" >&2; exit 4; }
checksum_verify "$archive"
require_service postgres
require_restore_confirmation "$POSTGRES_DB"

compose exec -T postgres pg_restore \
    --username "$POSTGRES_USER" \
    --dbname "$POSTGRES_DB" \
    --clean --if-exists --no-owner < "$archive"

