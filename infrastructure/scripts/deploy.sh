#!/bin/sh
set -eu

owner=${1:?Usage: deploy.sh <registry-owner> <version> <rollback-version>}
version=${2:?Usage: deploy.sh <registry-owner> <version> <rollback-version>}
rollback_version=${3:?Usage: deploy.sh <registry-owner> <version> <rollback-version>}
ENV=production
export ENV
. "$(dirname "$0")/common.sh"

deploy_version() {
    selected_version=$1
    NGINX_RUNTIME_IMAGE="ghcr.io/$owner/infrastructure-nginx:$selected_version"
    POSTGRES_RUNTIME_IMAGE="ghcr.io/$owner/infrastructure-postgres:$selected_version"
    REDIS_RUNTIME_IMAGE="ghcr.io/$owner/infrastructure-redis:$selected_version"
    RABBITMQ_RUNTIME_IMAGE="ghcr.io/$owner/infrastructure-rabbitmq:$selected_version"
    export NGINX_RUNTIME_IMAGE POSTGRES_RUNTIME_IMAGE REDIS_RUNTIME_IMAGE RABBITMQ_RUNTIME_IMAGE

    compose pull
    compose up --detach --remove-orphans --wait --wait-timeout 180
}

if ! deploy_version "$version"; then
    echo "Deployment failed; rolling back to $rollback_version" >&2
    deploy_version "$rollback_version"
    exit 1
fi

