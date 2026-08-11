#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPOSITORY_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)

if [ ! -f "$REPOSITORY_DIR/.env" ]; then
    echo "Missing $REPOSITORY_DIR/.env" >&2
    exit 2
fi

set -a
# shellcheck disable=SC1091
. "$REPOSITORY_DIR/.env"
set +a

ENVIRONMENT=${ENV:-local}
case "$ENVIRONMENT" in
    local|test|production) ;;
    *) echo "Unsupported ENV: $ENVIRONMENT" >&2; exit 2 ;;
esac

COMPOSE_PROJECT_NAME=${COMPOSE_PROJECT_NAME:-infrastructure}
PROJECT_NAME="${COMPOSE_PROJECT_NAME}-${ENVIRONMENT}"
COMPOSE_PROFILES=${COMPOSE_PROFILES:-postgres,redis,rabbitmq,monitoring,proxy}

compose() {
    COMPOSE_PROFILES="$COMPOSE_PROFILES" docker compose \
        --env-file "$REPOSITORY_DIR/.env" \
        --project-name "$PROJECT_NAME" \
        -f "$REPOSITORY_DIR/compose.yaml" \
        -f "$REPOSITORY_DIR/compose.$ENVIRONMENT.yaml" \
        "$@"
}

require_service() {
    service_id=$(compose ps --quiet "$1")
    if [ -z "$service_id" ]; then
        echo "Service '$1' is not running in project $PROJECT_NAME" >&2
        exit 3
    fi
}

BACKUP_PATH=${BACKUP_PATH:-./backups}
case "$BACKUP_PATH" in
    /*) BACKUP_DIR=$BACKUP_PATH ;;
    *) BACKUP_DIR=$REPOSITORY_DIR/${BACKUP_PATH#./} ;;
esac

case "$BACKUP_DIR" in
    /|"$REPOSITORY_DIR")
        echo "Unsafe BACKUP_PATH: $BACKUP_DIR" >&2
        exit 2
        ;;
esac

mkdir -p "$BACKUP_DIR"

checksum_create() {
    archive=$1
    if command -v sha256sum >/dev/null 2>&1; then
        (cd "$(dirname "$archive")" && sha256sum "$(basename "$archive")") > "$archive.sha256"
    else
        (cd "$(dirname "$archive")" && shasum -a 256 "$(basename "$archive")") > "$archive.sha256"
    fi
}

checksum_verify() {
    archive=$1
    test -f "$archive.sha256" || {
        echo "Missing checksum: $archive.sha256" >&2
        exit 4
    }
    if command -v sha256sum >/dev/null 2>&1; then
        (cd "$(dirname "$archive")" && sha256sum -c "$(basename "$archive").sha256")
    else
        (cd "$(dirname "$archive")" && shasum -a 256 -c "$(basename "$archive").sha256")
    fi
}

require_restore_confirmation() {
    expected="$PROJECT_NAME:$1"
    if [ "${RESTORE_CONFIRM:-}" != "$expected" ]; then
        echo "Restore changes live data." >&2
        echo "Retry with RESTORE_CONFIRM='$expected'" >&2
        exit 5
    fi
}

