#!/usr/bin/env bash
set -euo pipefail

INSTALL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${INSTALL_DIR}/.." && pwd)"
CALLICO_DIR="${PROJECT_ROOT}/callico"
ENV_FILE="${INSTALL_DIR}/production.env"
ENV_EXAMPLE="${ENV_FILE}.example"
COMPOSE_ARGS=(
  --project-name callico-prod
  --project-directory "${CALLICO_DIR}"
  -f "${CALLICO_DIR}/docker-compose.yml"
  --env-file "${ENV_FILE}"
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

if ! docker compose version >/dev/null 2>&1; then
  echo "docker compose v2 is required but was not found." >&2
  exit 1
fi

if [[ ! -f "${ENV_FILE}" ]]; then
  if [[ -f "${ENV_EXAMPLE}" ]]; then
    cp "${ENV_EXAMPLE}" "${ENV_FILE}" \
      && echo "A template has been copied to ${ENV_FILE}." >&2
  fi
  cat >&2 <<'MSG'
Missing production environment file.
Please review it, adjust the secrets/domains and re-run this script.
MSG
  exit 1
fi

if [[ ! -s "${ENV_FILE}" ]]; then
  echo "${ENV_FILE} exists but is empty. Please configure it before continuing." >&2
  exit 1
fi

set -a
source "${ENV_FILE}"
set +a

export CALLICO_ENV_FILE="${CALLICO_ENV_FILE:-${ENV_FILE}}"

ACME_FILE_RELATIVE="${TRAEFIK_CERTS_DIR:-./traefik/certs}/acme.json"
if [[ "${ACME_FILE_RELATIVE}" = /* ]]; then
  ACME_FILE="${ACME_FILE_RELATIVE}"
else
  ACME_FILE="${CALLICO_DIR}/${ACME_FILE_RELATIVE#./}"
fi
mkdir -p "$(dirname "${ACME_FILE}")"
if [[ ! -f "${ACME_FILE}" ]]; then
  touch "${ACME_FILE}"
fi
chmod 600 "${ACME_FILE}"

if [[ -z "${DJANGO_SUPERUSER_PASSWORD:-}" ]]; then
  echo "DJANGO_SUPERUSER_PASSWORD must be set in ${ENV_FILE}." >&2
  exit 1
fi

echo "Starting Callico stack..."
docker compose "${COMPOSE_ARGS[@]}" up -d

echo "Running database migrations..."
docker compose "${COMPOSE_ARGS[@]}" run --rm callico django-admin migrate

echo "Collecting static files..."
docker compose "${COMPOSE_ARGS[@]}" run --rm callico django-admin collectstatic --noinput

echo "Creating Django superuser (will be skipped if it already exists)..."
if ! docker compose "${COMPOSE_ARGS[@]}" run --rm \
  -e DJANGO_SUPERUSER_USERNAME \
  -e DJANGO_SUPERUSER_EMAIL \
  -e DJANGO_SUPERUSER_PASSWORD \
  -e DJANGO_SUPERUSER_FIRST_NAME \
  -e DJANGO_SUPERUSER_LAST_NAME \
  callico django-admin createsuperuser --noinput
then
  echo "Superuser creation skipped (probably already exists)." >&2
fi

echo "Callico is now running at ${INSTANCE_URL:-https://callico.example.com}."
