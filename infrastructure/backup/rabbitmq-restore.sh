#!/bin/sh
set -eu
. "$(dirname "$0")/../scripts/common.sh"

archive=${1:?Usage: rabbitmq-restore.sh <archive.json>}
test -f "$archive" || { echo "Archive not found: $archive" >&2; exit 4; }
checksum_verify "$archive"
require_service rabbitmq
require_restore_confirmation rabbitmq

compose exec -T rabbitmq rabbitmqctl import_definitions - < "$archive"
