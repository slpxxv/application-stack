#!/bin/sh
set -eu

ENV=test
export ENV
. "$(dirname "$0")/common.sh"

cleanup() {
    compose down --volumes --remove-orphans
}
trap cleanup EXIT HUP INT TERM

compose up --detach --build --wait --wait-timeout 180
compose ps
