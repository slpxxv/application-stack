#!/bin/sh
set -eu
. "$(dirname "$0")/../scripts/common.sh"

retention=${BACKUP_RETENTION_DAYS:-14}
case "$retention" in
    ''|*[!0-9]*) echo "BACKUP_RETENTION_DAYS must be a non-negative integer" >&2; exit 2 ;;
esac

find "$BACKUP_DIR" -type f \
    \( -name '*.dump' -o -name '*.rdb' -o -name '*.json' -o -name '*.sha256' \) \
    -mtime "+$retention" -print -delete

