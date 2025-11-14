#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
TEMPLATE_DIR="${REPO_ROOT}/templates"

DEFAULT_TARGET_DIR="/opt/callico"
DEFAULT_GIT_URL="https://gitlab.teklia.com/callico/callico.git"

DOMAIN=""
LE_EMAIL=""
ADMIN_USERNAME=""
ADMIN_EMAIL=""
ADMIN_PASSWORD=""
TARGET_DIR="${DEFAULT_TARGET_DIR}"
GIT_URL="${DEFAULT_GIT_URL}"
INSTALL_SYSTEMD=1
FORCE=0
PASSWORD_FILE=""

usage() {
  cat <<USAGE
Usage: sudo $(basename "$0") --domain <domaine> --letsencrypt-email <email> \
             --admin-username <nom> --admin-email <email> [options]

Options :
  --domain VALUE              Domaine public (obligatoire)
  --letsencrypt-email VALUE   Email Let's Encrypt (obligatoire)
  --admin-username VALUE      Nom du super utilisateur Django (obligatoire)
  --admin-email VALUE         Email du super utilisateur Django (obligatoire)
  --admin-password VALUE      Mot de passe du super utilisateur (recommandé)
  --admin-password-file PATH  Lire le mot de passe depuis un fichier sécurisé
  --target-dir PATH           Répertoire cible (défaut : ${DEFAULT_TARGET_DIR})
  --git-url URL               URL Git à cloner (défaut : ${DEFAULT_GIT_URL})
  --force                     Supprime le répertoire cible s'il existe déjà
  --skip-systemd              N'installe pas le service systemd
  -h, --help                  Affiche cette aide
USAGE
}

log() {
  echo "[install] $*"
}

error() {
  echo "[install][error] $*" >&2
  exit 1
}

require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    error "La commande requise '$cmd' est introuvable."
  fi
}

escape_squote() {
  sed "s/'/'\\''/g" <<<"$1"
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --domain)
      DOMAIN="$2"; shift 2 ;;
    --letsencrypt-email)
      LE_EMAIL="$2"; shift 2 ;;
    --admin-username)
      ADMIN_USERNAME="$2"; shift 2 ;;
    --admin-email)
      ADMIN_EMAIL="$2"; shift 2 ;;
    --admin-password)
      ADMIN_PASSWORD="$2"; shift 2 ;;
    --admin-password-file)
      PASSWORD_FILE="$2"; shift 2 ;;
    --target-dir)
      TARGET_DIR="$2"; shift 2 ;;
    --git-url)
      GIT_URL="$2"; shift 2 ;;
    --force)
      FORCE=1; shift ;;
    --skip-systemd)
      INSTALL_SYSTEMD=0; shift ;;
    -h|--help)
      usage; exit 0 ;;
    *)
      error "Option inconnue : $1" ;;
  esac
done

if [[ $(id -u) -ne 0 ]]; then
  error "Ce script doit être exécuté avec les privilèges root (sudo)."
fi

[[ -n "$DOMAIN" ]] || error "--domain est obligatoire"
[[ -n "$LE_EMAIL" ]] || error "--letsencrypt-email est obligatoire"
[[ -n "$ADMIN_USERNAME" ]] || error "--admin-username est obligatoire"
[[ -n "$ADMIN_EMAIL" ]] || error "--admin-email est obligatoire"

if [[ -n "$PASSWORD_FILE" ]]; then
  if [[ ! -f "$PASSWORD_FILE" ]]; then
    error "Le fichier mot de passe '$PASSWORD_FILE' est introuvable."
  fi
  ADMIN_PASSWORD="$(<"$PASSWORD_FILE")"
fi

if [[ -z "$ADMIN_PASSWORD" ]]; then
  error "Un mot de passe administrateur doit être fourni via --admin-password ou --admin-password-file."
fi

require_cmd git
require_cmd docker

if ! docker info >/dev/null 2>&1; then
  error "Docker n'est pas fonctionnel pour l'utilisateur courant."
fi

if ! docker compose version >/dev/null 2>&1; then
  error "Le plugin 'docker compose' est requis."
fi

prepare_target_directory() {
  if [[ -d "$TARGET_DIR" ]]; then
    if [[ $FORCE -eq 1 ]]; then
      log "Suppression du répertoire existant ${TARGET_DIR} (option --force)."
      rm -rf "$TARGET_DIR"
    else
      error "Le répertoire ${TARGET_DIR} existe déjà. Utilisez --force pour le remplacer."
    fi
  fi
  mkdir -p "$TARGET_DIR"
}

clone_callico() {
  log "Clonage du dépôt Callico (${GIT_URL})."
  git clone --depth 1 "$GIT_URL" "$TARGET_DIR"
}

render_template() {
  local template_path="$1"
  local destination="$2"
  shift 2
  local content
  content="$(<"$template_path")"
  for pair in "$@"; do
    local key="${pair%%=*}"
    local value="${pair#*=}"
    content="${content//"__${key}__"/${value}}"
  done
  printf '%s\n' "$content" > "$destination"
}

configure_traefik() {
  log "Configuration de Traefik et HTTPS."
  render_template \
    "${TEMPLATE_DIR}/docker-compose.override.yml.tpl" \
    "${TARGET_DIR}/docker-compose.override.yml" \
    "DOMAIN=${DOMAIN}" \
    "LE_EMAIL=${LE_EMAIL}"

  mkdir -p "${TARGET_DIR}/letsencrypt"
  local acme_file="${TARGET_DIR}/letsencrypt/acme.json"
  touch "$acme_file"
  chmod 600 "$acme_file"
}

setup_systemd_service() {
  if [[ $INSTALL_SYSTEMD -ne 1 ]]; then
    log "Installation systemd désactivée (--skip-systemd)."
    return
  fi

  local service_path="/etc/systemd/system/callico.service"
  log "Installation du service systemd (${service_path})."
  render_template \
    "${TEMPLATE_DIR}/callico.service.tpl" \
    "$service_path" \
    "TARGET_DIR=${TARGET_DIR}"

  systemctl daemon-reload
  systemctl enable callico.service
  systemctl start callico.service
}

start_stack() {
  log "Démarrage de la pile Docker."
  ( cd "$TARGET_DIR" && docker compose pull )
  ( cd "$TARGET_DIR" && docker compose up -d )
}

wait_for_service() {
  local service="$1"
  local retries=60
  local container_id=""
  while (( retries > 0 )); do
    container_id="$(cd "$TARGET_DIR" && docker compose ps -q "$service")"
    if [[ -n "$container_id" ]]; then
      local status
      status="$(docker inspect -f '{{.State.Status}}' "$container_id" 2>/dev/null || true)"
      if [[ "$status" == "running" ]]; then
        return 0
      fi
    fi
    sleep 2
    retries=$((retries - 1))
  done
  error "Le service ${service} n'est pas opérationnel après l'attente."
}

run_django_commands() {
  log "Exécution des migrations Django."
  ( cd "$TARGET_DIR" && docker compose exec -T callico bash -lc "django-admin migrate" )

  log "Création du super utilisateur Django (${ADMIN_USERNAME})."
  local esc_user esc_email esc_password
  esc_user="$(escape_squote "$ADMIN_USERNAME")"
  esc_email="$(escape_squote "$ADMIN_EMAIL")"
  esc_password="$(escape_squote "$ADMIN_PASSWORD")"
  set +e
  ( cd "$TARGET_DIR" && docker compose exec -T callico bash -lc "DJANGO_SUPERUSER_USERNAME='${esc_user}' DJANGO_SUPERUSER_EMAIL='${esc_email}' DJANGO_SUPERUSER_PASSWORD='${esc_password}' django-admin createsuperuser --noinput" )
  local status=$?
  set -e
  if [[ $status -ne 0 ]]; then
    error "La création du super utilisateur a échoué. Consultez les journaux avec 'docker compose logs callico'."
  fi
}

final_instructions() {
  log "Installation terminée."
  log "Callico devrait être accessible sur https://${DOMAIN} après l'émission du certificat."
  if [[ $INSTALL_SYSTEMD -eq 1 ]]; then
    log "Le service systemd 'callico.service' assure désormais le démarrage automatique."
  fi
}

prepare_target_directory
clone_callico
configure_traefik
start_stack
wait_for_service "callico"
run_django_commands
setup_systemd_service
final_instructions
