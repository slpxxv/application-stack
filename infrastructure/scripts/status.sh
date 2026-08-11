#!/bin/sh
set -eu
. "$(dirname "$0")/common.sh"

compose ps --all
printf '\nHealth summary\n'
for service in $(compose config --services); do
    container_id=$(compose ps --quiet "$service")
    if [ -z "$container_id" ]; then
        printf '%-16s %s\n' "$service" stopped
        continue
    fi
    health=$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' "$container_id")
    printf '%-16s %s\n' "$service" "$health"
done
