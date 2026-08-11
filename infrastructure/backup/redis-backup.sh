#!/bin/sh
set -eu
. "$(dirname "$0")/../scripts/common.sh"

require_service redis
timestamp=$(date -u +%Y%m%dT%H%M%SZ)
archive="$BACKUP_DIR/redis-${PROJECT_NAME}-${timestamp}.rdb"
trap 'rm -f "$archive" "$archive.sha256"' EXIT HUP INT TERM

compose exec -T redis sh -c \
    'REDISCLI_AUTH=$(cat "$REDIS_PASSWORD_FILE") redis-cli --user "$REDIS_USER" SAVE >/dev/null'
compose cp redis:/data/dump.rdb "$archive"
checksum_create "$archive"
trap - EXIT HUP INT TERM
printf '%s\n' "$archive"

