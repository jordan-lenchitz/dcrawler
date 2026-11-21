#!/usr/bin/env bash
set -euo pipefail

export DCRAWL_DB_DIR="${DCRAWL_DB_DIR:-/data/dcrawl}"
mkdir -p "$DCRAWL_DB_DIR"

# Initialize the shared MUMPS database once at container startup and seed ^TYPE
set +eu
for v in $(compgen -v ydb_) $(compgen -v gtm); do unset "$v"; done
export ydb_dir="$DCRAWL_DB_DIR"
source /usr/local/etc/ydb_env_set >/dev/null
set -eu
export ydb_routines="/app/src ${ydb_routines:-}"
export gtmroutines="/app/src ${gtmroutines:-}"

cd /app
mumps -run 'SEED^DCTYPE'

MODE="${DCRAWL_MODE:-auto}"
if [[ "${1:-}" == "web" ]]; then
  MODE="web"
elif [[ "${1:-}" == "cli" || "${1:-}" == "play" ]]; then
  MODE="cli"
elif [[ "$MODE" == "auto" ]]; then
  if [[ -n "${K_SERVICE:-}" || ! -t 0 ]]; then
    MODE="web"
  else
    MODE="cli"
  fi
fi

if [[ "$MODE" == "web" ]]; then
  export DCRAWL_IDLE_SEC="${DCRAWL_IDLE_SEC:-900}"
  PORT="${PORT:-8080}"
  MAX_CLIENTS="${DCRAWL_MAX_CLIENTS:-20}"
  exec ttyd \
    --writable \
    -p "$PORT" \
    --max-clients "$MAX_CLIENTS" \
    --ping-interval 25 \
    -t titleFixed=dcrawl \
    -t fontSize=18 \
    -t 'theme={"background":"#0d1117","foreground":"#e6edf3","cursor":"#58a6ff"}' \
    /app/scripts/run-session.sh
else
  export DCRAWL_IDLE_SEC="${DCRAWL_IDLE_SEC:-0}"
  exec /app/scripts/run-session.sh
fi
