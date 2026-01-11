#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  cat <<'EOF'
Flyway runner (Docker)

Usage:
  ./app/flyway/flyway.sh <command> [args...]

Examples:
  ./app/flyway/flyway.sh info
  ./app/flyway/flyway.sh migrate
  ./app/flyway/flyway.sh validate
  ./app/flyway/flyway.sh repair

Configuration:
  - Create ./app/flyway/.env from ./app/flyway/.env.example
  - Or set env vars: FLYWAY_URL, FLYWAY_USER, FLYWAY_PASSWORD, ...
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" || "${1:-}" == "" ]]; then
  usage
  exit 0
fi

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    printf "\nERROR: Missing required command: %s\n" "$1" >&2
    exit 1
  }
}

need_cmd docker

ENV_FILE="$SCRIPT_DIR/.env"
if [[ ! -f "$ENV_FILE" ]]; then
  printf "\nNOTE: %s not found.\n" "$ENV_FILE" >&2
  printf "      Copy %s to %s and set DB credentials, or export FLYWAY_* vars.\n\n" "$SCRIPT_DIR/.env.example" "$ENV_FILE" >&2
fi

FLYWAY_IMAGE="${FLYWAY_IMAGE:-flyway/flyway:10}"
FLYWAY_DOCKER_NETWORK="${FLYWAY_DOCKER_NETWORK:-}"

DOCKER_ARGS=(run --rm)

# Attach a TTY when available.
if [[ -t 0 && -t 1 ]]; then
  DOCKER_ARGS+=( -it )
fi

# Ensure Linux containers can reach the host via host.docker.internal.
UNAME_S="$(uname -s 2>/dev/null || true)"
if [[ "$UNAME_S" == "Linux" ]]; then
  DOCKER_ARGS+=( --add-host=host.docker.internal:host-gateway )
fi

DOCKER_ARGS+=(
  -v "$SCRIPT_DIR/sql:/flyway/sql:ro"
)

if [[ -n "$FLYWAY_DOCKER_NETWORK" ]]; then
  DOCKER_ARGS+=( --network "$FLYWAY_DOCKER_NETWORK" )
fi

if [[ -f "$ENV_FILE" ]]; then
  DOCKER_ARGS+=( --env-file "$ENV_FILE" )
fi

DOCKER_ARGS+=( "$FLYWAY_IMAGE" )

exec docker "${DOCKER_ARGS[@]}" "$@"
