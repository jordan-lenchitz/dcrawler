#!/usr/bin/env bash
set -euo pipefail

export TERM="${TERM:-xterm-256color}"
export LANG="${LANG:-C.UTF-8}"
DB_DIR="${DCRAWL_DB_DIR:-/data/dcrawl}"

# Source MUMPS runtime environment pointing at the shared database
set +eu
for v in $(compgen -v ydb_) $(compgen -v gtm); do unset "$v"; done
export ydb_dir="$DB_DIR"
source /usr/local/etc/ydb_env_set >/dev/null
set -eu
export ydb_routines="/app/src ${ydb_routines:-}"
export gtmroutines="/app/src ${gtmroutines:-}"

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
trap cleanup HUP TERM INT

RC=0
wait "$MUMPS_PID" || RC=$?
# Belt-and-suspenders cleanup in case process terminated unexpectedly
mumps -run %XCMD "D CLEANUP^DCRAWL($MUMPS_PID)" >/dev/null 2>&1 || true
exit "$RC"
