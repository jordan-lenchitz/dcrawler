#!/usr/bin/env bash
set -euo pipefail

umask 077
ulimit -c 0
ulimit -n 256 2>/dev/null || true

# Disable terminal signal keys (^C, ^\, ^Z) and XON/XOFF flow control on the PTY
stty -isig -ixon -ixoff 2>/dev/null || true
trap '' INT QUIT TSTP

export TERM="${TERM:-xterm-256color}"
export LANG="${LANG:-C.UTF-8}"
DB_DIR="${DCRAWL_DB_DIR:-/data/dcrawl}"

# Locate and source MUMPS runtime environment pointing at the shared database
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
export ydb_dir="$DB_DIR"
YDB_ENV_LOG="$(mktemp)"
source "$YDB_ENV_SET" >"$YDB_ENV_LOG" 2>&1
YDB_RC=$?
set -eu
if [[ "$YDB_RC" -ne 0 ]] || ! command -v mumps >/dev/null 2>&1; then
  echo "Error: failed to initialize YottaDB environment (rc=${YDB_RC}, arch=$(uname -m))." >&2
  cat "$YDB_ENV_LOG" >&2 || true
  rm -f "$YDB_ENV_LOG"
  exit 1
fi
rm -f "$YDB_ENV_LOG"

export ydb_routines="/app/src ${ydb_routines:-}"
export gtmroutines="/app/src ${gtmroutines:-}"

# Prevent YottaDB/GT.M from ever dropping to direct mode (YDB>/GTM>) on Ctrl-C or errors
export ydb_nocenable=1
export ydb_etrap="ZHALT 1"
export ydb_zinterrupt="ZHALT 1"
export gtm_nocenable=1
export gtm_etrap="ZHALT 1"
export gtm_zinterrupt="ZHALT 1"

cd /app

# Run game preserving PTY stdin (<&0) and guarantee ^G($J) cleanup on abrupt browser disconnect
mumps -run '^DCRAWL' <&0 &
MUMPS_PID=$!

cleanup() {
  kill -HUP "$MUMPS_PID" 2>/dev/null || true
  wait "$MUMPS_PID" 2>/dev/null || true
  mumps -run %XCMD "D CLEANUP^DCRAWL($MUMPS_PID)" >/dev/null 2>&1 || true
  exit 0
}
trap cleanup HUP TERM

RC=0
wait "$MUMPS_PID" || RC=$?
# Belt-and-suspenders cleanup in case process terminated unexpectedly
mumps -run %XCMD "D CLEANUP^DCRAWL($MUMPS_PID)" >/dev/null 2>&1 || true
exit "$RC"
