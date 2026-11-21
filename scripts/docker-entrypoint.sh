#!/usr/bin/env bash
set -euo pipefail

umask 077

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
export ydb_etrap="ZHALT 1"
export gtm_etrap="ZHALT 1"

cd /app
mumps -run 'SEED^DCTYPE'

MODE="${DCRAWL_MODE:-auto}"
if [[ "${1:-}" == "web" || "${1:-}" == "--web" ]]; then
  MODE="web"
elif [[ "${1:-}" == "cli" || "${1:-}" == "--cli" || "${1:-}" == "play" ]]; then
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
  TTYD_PORT="${DCRAWL_TTYD_PORT:-7681}"
  MAX_CLIENTS="${DCRAWL_MAX_CLIENTS:-20}"

  ORIGIN_DEFAULT=0
  TTYD_ORIGIN_ARGS=(--check-origin)
  # Opt-in bypass strictly for local proxies (e.g. Cloud Shell Web Preview); never active on Cloud Run
  if [[ "${DCRAWL_ALLOW_PREVIEW_ORIGIN:-0}" == "1" && -z "${K_SERVICE:-}" ]]; then
    ORIGIN_DEFAULT=1
    TTYD_ORIGIN_ARGS=()
  fi

  mkdir -p /tmp/nginx/body /tmp/nginx/proxy /tmp/nginx/fastcgi /tmp/nginx/uwsgi /tmp/nginx/scgi
  sed -e "s/__PORT__/${PORT}/g" \
      -e "s/__TTYD_PORT__/${TTYD_PORT}/g" \
      -e "s/__ORIGIN_DEFAULT__/${ORIGIN_DEFAULT}/g" \
    /app/config/nginx.conf > /tmp/nginx/nginx.conf

  ttyd \
    --writable \
    "${TTYD_ORIGIN_ARGS[@]}" \
    -i 127.0.0.1 \
    -p "$TTYD_PORT" \
    --max-clients "$MAX_CLIENTS" \
    --ping-interval 25 \
    -t titleFixed=dcrawl \
    -t fontSize=18 \
    -t disableReconnect=true \
    -t disableLeaveAlert=true \
    -t 'theme={"background":"#0d1117","foreground":"#e6edf3","cursor":"#58a6ff"}' \
    /app/scripts/run-session.sh &
  TTYD_PID=$!

  nginx -c /tmp/nginx/nginx.conf -g 'daemon off;' &
  NGINX_PID=$!

  shutdown() {
    kill -TERM "$NGINX_PID" "$TTYD_PID" 2>/dev/null || true
    wait "$NGINX_PID" "$TTYD_PID" 2>/dev/null || true
    exit 0
  }
  trap shutdown TERM INT HUP

  # Exit immediately if either ttyd or nginx dies so the orchestrator restarts cleanly
  wait -n "$TTYD_PID" "$NGINX_PID"
  RC=$?
  kill -TERM "$NGINX_PID" "$TTYD_PID" 2>/dev/null || true
  wait "$NGINX_PID" "$TTYD_PID" 2>/dev/null || true
  exit "$RC"
else
  export DCRAWL_IDLE_SEC="${DCRAWL_IDLE_SEC:-0}"
  exec /app/scripts/run-session.sh
fi
