#!/bin/sh
set -eu
. "$(dirname "$0")/../scripts/common.sh"

archive=${1:?Usage: redis-restore.sh <archive.rdb>}
test -f "$archive" || { echo "Archive not found: $archive" >&2; exit 4; }
checksum_verify "$archive"
require_service redis
require_restore_confirmation redis

compose stop redis
compose cp "$archive" redis:/data/dump.rdb
compose start redis

