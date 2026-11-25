#!/usr/bin/env bash
set -euo pipefail

umask 077

export DCRAWL_DB_DIR="${DCRAWL_DB_DIR:-/data/dcrawl}"
mkdir -p "$DCRAWL_DB_DIR"

# Locate and initialize the shared MUMPS runtime environment
YDB_ENV_SET="/usr/local/etc/ydb_env_set"
if [[ ! -f "$YDB_ENV_SET" ]]; then
  YDB_ENV_SET="$(find /opt/yottadb /usr/local/lib/yottadb -name ydb_env_set 2>/dev/null | head -n 1 || true)"
fi
if [[ -z "$YDB_ENV_SET" || ! -f "$YDB_ENV_SET" ]]; then
  echo "Error: could not locate ydb_env_set" >&2
  exit 1
fi

set +eu
for v in $(compgen -v ydb_) $(compgen -v gtm); do unset "$v"; done
export ydb_dir="$DCRAWL_DB_DIR"
YDB_ENV_LOG="$(mktemp)"
source "$YDB_ENV_SET" >"$YDB_ENV_LOG" 2>&1
YDB_RC=$?
set -eu
if [[ "$YDB_RC" -ne 0 ]] || ! command -v mumps >/dev/null 2>&1; then
  echo "Error: failed to initialize YottaDB environment (rc=${YDB_RC}, arch=$(uname -m))." >&2
  echo "If running on Apple Silicon / ARM64, ensure you are using a native linux/arm64 image." >&2
  cat "$YDB_ENV_LOG" >&2 || true
  rm -f "$YDB_ENV_LOG"
  exit 1
fi
rm -f "$YDB_ENV_LOG"

export ydb_routines="/app/src ${ydb_routines:-}"
export gtmroutines="/app/src ${gtmroutines:-}"
export ydb_etrap="ZHALT 1"
export gtm_etrap="ZHALT 1"

# Recover/rundown existing database files for this architecture after unclean stop or hostname change
for dat in "$DCRAWL_DB_DIR"/${ydb_rel:-*}/g/*.dat; do
  if [[ -f "$dat" ]]; then
    mupip rundown -file "$dat" >/dev/null 2>&1 || true
  fi
done
mupip rundown -region "*" >/dev/null 2>&1 || true

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
