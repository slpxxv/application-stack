#!/bin/sh
set -eu

password_file=${RABBITMQ_DEFAULT_PASS_FILE:?RABBITMQ_DEFAULT_PASS_FILE is required}
test -r "$password_file" || {
    echo "RabbitMQ password file is not readable: $password_file" >&2
    exit 1
}

RABBITMQ_DEFAULT_PASS=$(cat "$password_file")
test -n "$RABBITMQ_DEFAULT_PASS" || {
    echo "RabbitMQ password must not be empty" >&2
    exit 1
}
export RABBITMQ_DEFAULT_PASS
unset RABBITMQ_DEFAULT_PASS_FILE

exec docker-entrypoint.sh "$@"

