#!/usr/bin/env bash
# setup.sh — start the webserver stack (nginx + php-fpm + mariadb + postgres).
#
# Tracked files (docker-compose.yml, nginx/, php/, www/) are the source of
# truth and are NEVER overwritten. This script only:
#   1. ensures .env exists (copies .env.example on first run),
#   2. checks the host HTTP port is free,
#   3. runs `docker compose up -d --build`.
#
# Usage:
#   bash setup.sh                  # start everything
#   bash setup.sh --port=8080      # override nginx host port for this run
#   bash setup.sh --reset          # down -v (delete named volumes) + fresh up
#   bash setup.sh --down           # stop and remove containers, keep volumes
set -euo pipefail

HTTP_PORT_OVERRIDE=""
DO_RESET=0
DO_DOWN=0

usage() {
  cat <<'EOF'
Usage: bash setup.sh [options]

Options:
  --port=<port>   host port for nginx (default: WEB_HTTP_PORT from .env, else 8080)
  --reset         docker compose down -v, then rebuild from scratch (DELETES db data)
  --down          docker compose down (stop stack, keep db data)
  -h, --help      show this help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --port=*) HTTP_PORT_OVERRIDE="${1#*=}"; shift ;;
    --port)   HTTP_PORT_OVERRIDE="${2:-}"; shift 2 ;;
    --reset)  DO_RESET=1; shift ;;
    --down)   DO_DOWN=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown argument: $1" >&2; usage; exit 1 ;;
  esac
done

info() { printf '[INFO]  %s\n' "$*"; }
die()  { printf '[ERROR] %s\n' "$*" >&2; exit 1; }

command -v docker >/dev/null 2>&1 || die "docker not found in PATH"
docker compose version >/dev/null 2>&1 || die "docker compose (v2) not available"

# --- .env bootstrap (never overwrite an existing .env) ---
if [[ ! -f .env ]]; then
  [[ -f .env.example ]] || die ".env.example missing — cannot bootstrap .env"
  cp .env.example .env
  info "created .env from .env.example — edit passwords before sharing/production use"
fi

# --- optional port override for this run only ---
if [[ -n "$HTTP_PORT_OVERRIDE" ]]; then
  [[ "$HTTP_PORT_OVERRIDE" =~ ^[0-9]+$ ]] || die "invalid --port: $HTTP_PORT_OVERRIDE"
  export WEB_HTTP_PORT="$HTTP_PORT_OVERRIDE"
  info "using WEB_HTTP_PORT=$WEB_HTTP_PORT (override, not written to .env)"
fi

# shellcheck disable=SC1091
set -a; source ./.env; set +a
HTTP_PORT="${WEB_HTTP_PORT:-8080}"

port_in_use() {
  local p="$1"
  if command -v lsof >/dev/null 2>&1; then
    lsof -nP -iTCP:"$p" -sTCP:LISTEN >/dev/null 2>&1 && return 0
  elif command -v ss >/dev/null 2>&1; then
    ss -ltn "sport = :$p" 2>/dev/null | grep -q LISTEN && return 0
  elif command -v netstat >/dev/null 2>&1; then
    netstat -ltn 2>/dev/null | grep -qE "[:.]$p[[:space:]]" && return 0
  fi
  return 1
}

if [[ "$DO_DOWN" -eq 1 ]]; then
  info "stopping stack (volumes kept) …"
  docker compose down --remove-orphans
  exit 0
fi

if [[ "$DO_RESET" -eq 1 ]]; then
  read -r -p "This DELETES all db data in named volumes. Continue? [y/N] " ans
  [[ "$ans" =~ ^[Yy]$ ]] || { info "aborted"; exit 0; }
  info "resetting stack (down -v) …"
  docker compose down -v --remove-orphans
fi

# Only check the port when we are about to start containers.
if [[ "$DO_RESET" -eq 1 ]] || ! docker compose ps --status running 2>/dev/null | grep -q .; then
  if port_in_use "$HTTP_PORT"; then
    die "host port $HTTP_PORT is already in use — pass --port=<free port> or free the port"
  fi
fi

info "starting stack (first run builds the PHP image — may take a minute) …"
docker compose up -d --build --remove-orphans

echo
docker compose ps
echo
info "web:      http://localhost:${HTTP_PORT}"
info "mariadb:  localhost:3306"
info "postgres: localhost:5432"
info "logs:     docker compose logs -f nginx php"
info "stop:     bash setup.sh --down  (or: docker compose down)"
