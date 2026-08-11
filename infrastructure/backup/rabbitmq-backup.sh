#!/bin/sh
set -eu
. "$(dirname "$0")/../scripts/common.sh"

require_service rabbitmq
timestamp=$(date -u +%Y%m%dT%H%M%SZ)
archive="$BACKUP_DIR/rabbitmq-${PROJECT_NAME}-${timestamp}.json"
trap 'rm -f "$archive" "$archive.sha256"' EXIT HUP INT TERM

compose exec -T rabbitmq rabbitmqctl export_definitions - > "$archive"
checksum_create "$archive"
trap - EXIT HUP INT TERM
printf '%s\n' "$archive"
