#!/usr/bin/env bash
set -euo pipefail

DEFAULT_TARGET_DIR="/opt/callico"
TARGET_DIR="${DEFAULT_TARGET_DIR}"
PURGE_VOLUMES=0
REMOVE_SYSTEMD=1

usage() {
  cat <<USAGE
Usage: sudo $(basename "$0") [--target-dir <path>] [--purge-volumes] [--skip-systemd]

Options :
  --target-dir PATH   Répertoire d'installation (défaut : ${DEFAULT_TARGET_DIR})
  --purge-volumes     Supprime aussi les volumes Docker associés
  --skip-systemd      Ne tente pas de retirer le service systemd
  -h, --help          Affiche cette aide
USAGE
}

log() {
  echo "[uninstall] $*"
}

error() {
  echo "[uninstall][error] $*" >&2
  exit 1
}

require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    error "La commande requise '$cmd' est introuvable."
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target-dir)
      TARGET_DIR="$2"; shift 2 ;;
    --purge-volumes)
      PURGE_VOLUMES=1; shift ;;
    --skip-systemd)
      REMOVE_SYSTEMD=0; shift ;;
    -h|--help)
      usage; exit 0 ;;
    *)
      error "Option inconnue : $1" ;;
  esac
done

if [[ $(id -u) -ne 0 ]]; then
  error "Ce script doit être exécuté avec les privilèges root (sudo)."
fi

if [[ ! -d "$TARGET_DIR" ]]; then
  error "Le répertoire ${TARGET_DIR} est introuvable."
fi

require_cmd docker
if ! docker compose version >/dev/null 2>&1; then
  error "Le plugin 'docker compose' est requis pour arrêter la pile."
fi

down_stack() {
  if [[ -f "${TARGET_DIR}/docker-compose.yml" ]]; then
    log "Arrêt de la pile Docker."
    local args=(down --remove-orphans)
    if [[ $PURGE_VOLUMES -eq 1 ]]; then
      args+=(--volumes)
    fi
    ( cd "$TARGET_DIR" && docker compose "${args[@]}" ) || log "Avertissement : arrêt Docker partiel."
  else
    log "Aucun fichier docker-compose.yml trouvé, rien à arrêter."
  fi
}

remove_systemd() {
  if [[ $REMOVE_SYSTEMD -ne 1 ]]; then
    log "Suppression systemd ignorée (--skip-systemd)."
    return
  fi

  local service_path="/etc/systemd/system/callico.service"
  if [[ -f "$service_path" ]]; then
    log "Suppression du service systemd."
    systemctl stop callico.service || true
    systemctl disable callico.service || true
    rm -f "$service_path"
    systemctl daemon-reload
  else
    log "Aucun service systemd callico.service trouvé."
  fi
}

cleanup_files() {
  log "Suppression du répertoire ${TARGET_DIR}."
  rm -rf "$TARGET_DIR"
}

summary() {
  log "Désinstallation terminée."
}

down_stack
remove_systemd
cleanup_files
summary
