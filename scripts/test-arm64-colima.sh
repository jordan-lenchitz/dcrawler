#!/usr/bin/env bash
# Local end-to-end test script for dcrawler on Apple Silicon Macs (Colima / Docker Desktop, linux/arm64)
#
# Usage:
#   ./scripts/test-arm64-colima.sh              # Pull ghcr.io image & run full ARM64 test suite
#   ./scripts/test-arm64-colima.sh --build      # Build local Dockerfile for linux/arm64 & test
#   ./scripts/test-arm64-colima.sh --port 18080 # Use custom host port (default: 18080)
#   ./scripts/test-arm64-colima.sh --keep       # Keep web container running after tests pass
#   ./scripts/test-arm64-colima.sh --arch amd64 # Override expected arch (default: arm64)

set -euo pipefail

IMAGE="${IMAGE:-ghcr.io/jordan-lenchitz/dcrawler:latest}"
MODE="pull"
PORT="18080"
KEEP=0
EXPECT_ARCH="arm64"

while [ $# -gt 0 ]; do
    case "$1" in
        --build)
            MODE="build"
            IMAGE="dcrawler:local-arm64"
            ;;
        --pull)
            MODE="pull"
            ;;
        --port)
            PORT="$2"
            shift
            ;;
        --image)
            IMAGE="$2"
            shift
            ;;
        --arch)
            EXPECT_ARCH="$2"
            shift
            ;;
        --keep)
            KEEP=1
            ;;
        -h|--help)
            sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'
            exit 0
            ;;
        *)
            echo "Unknown argument: $1" >&2
            exit 1
            ;;
    esac
    shift
done

if [ "$EXPECT_ARCH" = "arm64" ]; then
    EXPECT_UNAME="aarch64"
else
    EXPECT_UNAME="x86_64"
fi

if [ "$MODE" = "build" ] && [ "$IMAGE" = "dcrawler:local-arm64" ]; then
    IMAGE="dcrawler:local-${EXPECT_ARCH}"
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
CONTAINER_NAME="dcrawler-test-$$"
VOLUME_NAME="dcrawler-test-data-$$"
BASE_URL="http://127.0.0.1:${PORT}"

# Colors (safe on macOS Terminal / iTerm2)
GREEN='\033[0;32m'
RED='\033[0;31m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASS_COUNT=0
step()  { printf "\n${CYAN}==> %s${NC}\n" "$1"; }
pass()  { PASS_COUNT=$((PASS_COUNT + 1)); printf "  ${GREEN}✓${NC} %s\n" "$1"; }
warn()  { printf "  ${YELLOW}!${NC} %s\n" "$1"; }
fail()  { printf "  ${RED}✗${NC} %s\n" "$1" >&2; exit 1; }

assert_contains() {
    local label="$1"
    local haystack="$2"
    local needle="$3"
    if [[ "$haystack" == *"$needle"* ]]; then
        pass "$label"
    else
        printf "  ${RED}Expected to find:${NC} %s\n" "$needle" >&2
        printf "  ${RED}Actual output:${NC}    %.500s\n" "$haystack" >&2
        fail "$label"
    fi
}

cleanup() {
    if [ "$KEEP" -eq 1 ]; then
        printf "\n${YELLOW}Keeping container '%s' running at %s (volume: %s)${NC}\n" "$CONTAINER_NAME" "$BASE_URL" "$VOLUME_NAME"
        printf "Stop later with: docker rm -f %s && docker volume rm %s\n" "$CONTAINER_NAME" "$VOLUME_NAME"
        return
    fi
    docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true
    docker volume rm "$VOLUME_NAME" >/dev/null 2>&1 || true
}
trap cleanup EXIT

wait_for_health() {
    local i
    for i in $(seq 1 30); do
        if curl -fsS "${BASE_URL}/healthz" >/dev/null 2>&1; then
            return 0
        fi
        sleep 1
    done
    echo "--- Container logs ---" >&2
    docker logs "$CONTAINER_NAME" >&2 || true
    fail "Server did not become healthy at ${BASE_URL}/healthz within 30s"
}

step "1. Checking Docker / Colima environment"
if ! command -v docker >/dev/null 2>&1; then
    fail "docker CLI not found in PATH"
fi

if ! docker info >/dev/null 2>&1; then
    if command -v colima >/dev/null 2>&1; then
        warn "Docker daemon not reachable; check Colima with: colima status"
        warn "Start native ARM64 Colima with: colima start --arch aarch64 --cpu 4 --memory 4"
    fi
    fail "Cannot reach Docker daemon"
fi

if command -v colima >/dev/null 2>&1; then
    colima status 2>&1 | sed 's/^/  /' || true
fi

DAEMON_ARCH="$(docker info --format '{{.Architecture}}')"
pass "Docker daemon reachable (arch: ${DAEMON_ARCH})"
if [ "$DAEMON_ARCH" != "$EXPECT_UNAME" ] && [ "$DAEMON_ARCH" != "$EXPECT_ARCH" ]; then
    warn "Docker daemon arch is '${DAEMON_ARCH}', expected '${EXPECT_UNAME}' (running under emulation or different arch)"
fi

step "2. Preparing linux/${EXPECT_ARCH} image (${MODE}: ${IMAGE})"
if [ "$MODE" = "build" ]; then
    docker build --platform "linux/${EXPECT_ARCH}" -t "$IMAGE" "$REPO_ROOT"
else
    docker pull --platform "linux/${EXPECT_ARCH}" "$IMAGE"
fi

IMG_ARCH="$(docker image inspect "$IMAGE" --format '{{.Architecture}}')"
assert_contains "Image architecture is ${EXPECT_ARCH}" "$IMG_ARCH" "$EXPECT_ARCH"

step "3. Verifying container CPU, non-root user, YottaDB & ttyd binaries"
ARCH_INFO="$(docker run --rm --platform "linux/${EXPECT_ARCH}" --entrypoint bash "$IMAGE" -c '
    set -euo pipefail
    echo "uid=$(id -un)"
    echo "uname=$(uname -m)"
    echo "ttyd=$(ttyd --version)"
    set +u
    for v in $(compgen -v ydb_) $(compgen -v gtm); do unset "$v"; done
    export ydb_dir=/data/dcrawl
    source /usr/local/etc/ydb_env_set >/dev/null
    set -u
    export ydb_routines="/app/src ${ydb_routines}"
    export gtmroutines="/app/src ${gtmroutines}"
    cd /app
    mumps -run %XCMD '\''W "zyrelease=",$ZYRELEASE,!,"zchset=",$ZCHSET,!'\''
')"
printf '%s\n' "$ARCH_INFO" | sed 's/^/  /'
assert_contains "Runs as non-root user dcrawl" "$ARCH_INFO" "uid=dcrawl"
assert_contains "Container uname -m is ${EXPECT_UNAME}" "$ARCH_INFO" "uname=${EXPECT_UNAME}"
assert_contains "YottaDB reports native ${EXPECT_UNAME}" "$ARCH_INFO" "${EXPECT_UNAME}"
assert_contains "ttyd binary executes natively" "$ARCH_INFO" "ttyd version"

step "4. Running native in-container MUMPS test suite (^DCTEST)"
if [ -f "${REPO_ROOT}/tests/DCTEST.m" ]; then
    MTEST_OUT="$(docker run --rm --platform "linux/${EXPECT_ARCH}" \
        -v "${REPO_ROOT}/tests:/tmp/tests:ro" \
        --entrypoint bash "$IMAGE" -c '
            set -euo pipefail
            set +u
            for v in $(compgen -v ydb_) $(compgen -v gtm); do unset "$v"; done
            export ydb_dir=/data/dcrawl
            source /usr/local/etc/ydb_env_set >/dev/null
            set -u
            mkdir -p /tmp/test_o
            mumps -object=/tmp/test_o/ /tmp/tests/DCTEST.m
            export ydb_routines="/app/src /tmp/test_o ${ydb_routines}"
            export gtmroutines="/app/src /tmp/test_o ${gtmroutines}"
            cd /app
            mumps -run "^DCTEST"
        ')"
    printf '%s\n' "$MTEST_OUT" | tail -n 10 | sed 's/^/  /'
    assert_contains "Native MUMPS ^DCTEST passed" "$MTEST_OUT" "ALL NATIVE MUMPS TESTS PASSED!"
else
    warn "tests/DCTEST.m not found locally; skipping ^DCTEST"
fi

step "5. Testing interactive CLI mode (PTY title screen, initials & clean quit)"
if command -v python3 >/dev/null 2>&1; then
    PTY_OUT="$(python3 - "$EXPECT_ARCH" "$IMAGE" <<'PY'
import os, pty, re, select, subprocess, sys, time

arch, image = sys.argv[1], sys.argv[2]
master, slave = pty.openpty()
proc = subprocess.Popen(
    ["docker", "run", "-it", "--rm", "--platform", f"linux/{arch}", image],
    stdin=slave, stdout=slave, stderr=slave, close_fds=True,
)
os.close(slave)

def drain(timeout=1.5):
    end, out = time.time() + timeout, ""
    while time.time() < end:
        if select.select([master], [], [], max(0.05, end - time.time()))[0]:
            try:
                chunk = os.read(master, 4096)
                if not chunk:
                    break
                out += chunk.decode("utf-8", errors="replace")
                end = time.time() + 0.25
            except OSError:
                break
    return out

buf = drain(5.0)
for tok in ("\r", "m", "a", "c", "\r", "q"):
    os.write(master, tok.encode("utf-8"))
    time.sleep(0.15)
    buf += drain(0.4)

rc = proc.wait(timeout=10)
os.close(master)
plain = re.sub(r"\x1b\[[?0-9;]*[A-Za-z]", "", buf)
print(f"RC={rc}")
print(plain)
sys.exit(0 if rc == 0 else 1)
PY
)"
    assert_contains "CLI exited cleanly (rc=0)" "$PTY_OUT" "RC=0"
    assert_contains "Title screen rendered" "$PTY_OUT" "where YOU are \$X and \$Y"
    assert_contains "Game HUD booted with initials MAC" "$PTY_OUT" "tag MAC"
    assert_contains "HUD displays floor 1/25" "$PTY_OUT" "flr 1/25"
else
    warn "python3 not found; skipping interactive PTY check"
fi

step "6. Starting web server mode with persistent Docker volume (${VOLUME_NAME})"
# Named Docker volume stays on Colima's native Linux filesystem for optimal YottaDB shared-memory/mmap safety
docker volume create "$VOLUME_NAME" >/dev/null
docker run -d \
    --name "$CONTAINER_NAME" \
    --platform "linux/${EXPECT_ARCH}" \
    -e DCRAWL_MODE=web \
    -p "${PORT}:8080" \
    -v "${VOLUME_NAME}:/data/dcrawl" \
    "$IMAGE" >/dev/null

wait_for_health
HEALTH="$(curl -fsS "${BASE_URL}/healthz")"
assert_contains "GET /healthz returns ok" "$HEALTH" "ok"

ROOT_HDRS="$(curl -fsSI "${BASE_URL}/")"
assert_contains "GET / sets X-Content-Type-Options: nosniff" "$ROOT_HDRS" "nosniff"
assert_contains "GET / sets Content-Security-Policy" "$ROOT_HDRS" "Content-Security-Policy"

ROOT_HTML="$(curl -fsS "${BASE_URL}/")"
assert_contains "GET / serves ttyd frontend" "$ROOT_HTML" "ttyd"

TOKEN_RES="$(curl -fsS "${BASE_URL}/token")"
assert_contains "GET /token returns token JSON" "$TOKEN_RES" '"token"'

WS_BAD_ORIGIN="$(curl -s -o /dev/null -w '%{http_code}' \
    -H 'Connection: Upgrade' \
    -H 'Upgrade: websocket' \
    -H 'Origin: https://evil.example' \
    "${BASE_URL}/ws")"
assert_contains "GET /ws rejects mismatched Origin with 403" "$WS_BAD_ORIGIN" "403"

step "7. Verifying YottaDB ^SCORES persistence across container restart"
docker exec "$CONTAINER_NAME" bash -c '
    set -euo pipefail
    set +u
    for v in $(compgen -v ydb_) $(compgen -v gtm); do unset "$v"; done
    export ydb_dir=/data/dcrawl
    source /usr/local/etc/ydb_env_set >/dev/null
    set -u
    export ydb_routines="/app/src ${ydb_routines}"
    export gtmroutines="/app/src ${gtmroutines}"
    mumps -run %XCMD '\''S ^G($J,"score")=42,^G($J,"floor")=3 D SETNAME^DCPLAY("MAC") S ID=$$RECORD^DCSCORE("WIN") K ^G($J)'\''
'

# Graceful stop (SIGTERM via tini) and restart with a fresh container ID/hostname on the same volume
docker stop "$CONTAINER_NAME" >/dev/null
docker rm "$CONTAINER_NAME" >/dev/null
docker run -d \
    --name "$CONTAINER_NAME" \
    --platform "linux/${EXPECT_ARCH}" \
    -e DCRAWL_MODE=web \
    -p "${PORT}:8080" \
    -v "${VOLUME_NAME}:/data/dcrawl" \
    "$IMAGE" >/dev/null

wait_for_health
LEADER="$(docker exec "$CONTAINER_NAME" bash -c '
    set -euo pipefail
    set +u
    for v in $(compgen -v ydb_) $(compgen -v gtm); do unset "$v"; done
    export ydb_dir=/data/dcrawl
    source /usr/local/etc/ydb_env_set >/dev/null
    set -u
    export ydb_routines="/app/src ${ydb_routines}"
    export gtmroutines="/app/src ${gtmroutines}"
    mumps -run %XCMD '\''W $$LEADER^DCSCORE,!'\''
')"
assert_contains "^SCORES leader persisted across restart" "$LEADER" "MAC^42^3^WIN"

printf "\n${GREEN}All %d checks passed on linux/%s (%s)!${NC}\n" "$PASS_COUNT" "$EXPECT_ARCH" "$IMAGE"
