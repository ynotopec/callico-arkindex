#!/usr/bin/env bash
set -euo pipefail

INSTALL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${INSTALL_DIR}/.." && pwd)"
CALLICO_DIR="${PROJECT_ROOT}/callico"
ENV_FILE="${INSTALL_DIR}/production.env"
COMPOSE_ARGS=(
  --project-name callico-prod
  --project-directory "${CALLICO_DIR}"
  -f "${CALLICO_DIR}/docker-compose.yml"
)

if [[ ! -d "${CALLICO_DIR}" ]]; then
  echo "Unable to locate Callico sources in ${CALLICO_DIR}." >&2
  echo "Please ensure the repository keeps the callico directory alongside install/." >&2
  exit 1
fi

if ! command -v docker >/dev/null 2>&1; then
  echo "docker is required but not installed." >&2
  exit 1
fi

if [[ -f "${ENV_FILE}" ]]; then
  COMPOSE_ARGS+=(--env-file "${ENV_FILE}")
  export CALLICO_ENV_FILE="${CALLICO_ENV_FILE:-${ENV_FILE}}"
else
  echo "${ENV_FILE} not found. Using template values for docker compose." >&2
fi

echo "Stopping Callico stack and removing containers, networks and volumes..."
docker compose "${COMPOSE_ARGS[@]}" down -v

echo "Callico has been removed. Persistent files such as production.env remain on disk."
