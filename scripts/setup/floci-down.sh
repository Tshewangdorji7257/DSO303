#!/usr/bin/env bash

# Pause Floci. YOUR STATE IS KEPT.
#
# docker compose stop     -> container stopped, state kept
# docker compose down     -> container removed, bind mount kept
# docker compose down -v  -> volumes destroyed
#
# NEVER use docker compose down -v for this course.

set -Eeuo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

source "$REPO_ROOT/configs/course.env"

docker compose stop

printf '\033[1;34m==>\033[0m Floci stopped. State preserved in %s\n' "$FLOCI_HOST_DATA_DIR"
