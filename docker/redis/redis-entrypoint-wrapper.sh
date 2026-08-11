#!/bin/sh
set -eu

password_file=${REDIS_PASSWORD_FILE:?REDIS_PASSWORD_FILE is required}
test -r "$password_file" || {
    echo "Redis password file is not readable: $password_file" >&2
    exit 1
}

password=$(cat "$password_file")
test -n "$password" || {
    echo "Redis password must not be empty" >&2
    exit 1
}

exec docker-entrypoint.sh "$@" \
    --user "${REDIS_USER:-infrastructure}" "on" ">${password}" "~*" "+@all" \
    --user default off
