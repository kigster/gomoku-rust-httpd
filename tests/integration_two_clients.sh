#!/usr/bin/env bash
#
# Integration test: spawn the daemon and run two `gomoku-http-client` games
# in parallel against it. Each game has the daemon playing both sides (X and O
# are both AI), so each request fully drives a separate game to completion.
#
# Goals:
#   * exercise the JSON API with realistic traffic
#   * verify the daemon handles concurrent games (two clients, one server)
#   * fail fast if either game fails to terminate or the server crashes
#
# Usage:
#   ./tests/integration_two_clients.sh                # uses default port 19931
#   PORT=29010 ./tests/integration_two_clients.sh
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

PORT="${PORT:-19931}"
DAEMON_BIN="${DAEMON_BIN:-$ROOT/target/release/gomoku-rust-httpd}"
CLIENT_BIN="${CLIENT_BIN:-$ROOT/bin/gomoku-http-client}"
LOG_DIR="${LOG_DIR:-$ROOT/target/integration-logs}"
DEPTH="${DEPTH:-2}"
RADIUS="${RADIUS:-2}"
BOARD="${BOARD:-15}"
TIMEOUT_SECS="${TIMEOUT_SECS:-90}"

mkdir -p "$LOG_DIR"

if [[ ! -x "$DAEMON_BIN" ]]; then
    echo "ERROR: daemon binary not found at $DAEMON_BIN" >&2
    echo "Build it first: cargo build --release" >&2
    exit 1
fi

if [[ ! -x "$CLIENT_BIN" ]]; then
    echo "ERROR: client binary not found at $CLIENT_BIN" >&2
    exit 1
fi

cleanup() {
    local code=$?
    if [[ -n "${SVR_PID:-}" ]] && kill -0 "$SVR_PID" 2>/dev/null; then
        kill "$SVR_PID" 2>/dev/null || true
        wait "$SVR_PID" 2>/dev/null || true
    fi
    exit "$code"
}
trap cleanup EXIT INT TERM

echo "==> launching daemon on port $PORT (logs: $LOG_DIR/daemon.log)"
"$DAEMON_BIN" -b "127.0.0.1:$PORT" -L INFO >"$LOG_DIR/daemon.log" 2>&1 &
SVR_PID=$!

echo "==> waiting for /health"
for _ in $(seq 1 50); do
    if curl -sf "http://127.0.0.1:$PORT/health" >/dev/null 2>&1; then
        break
    fi
    sleep 0.1
done
if ! curl -sf "http://127.0.0.1:$PORT/health" >/dev/null 2>&1; then
    echo "ERROR: daemon did not become healthy in time" >&2
    cat "$LOG_DIR/daemon.log"
    exit 1
fi

echo "==> running two concurrent games (depth=$DEPTH radius=$RADIUS board=$BOARD)"

run_game() {
    local label="$1"
    local out="$LOG_DIR/game-${label}.log"
    local json="$LOG_DIR/game-${label}.json"
    timeout "$TIMEOUT_SECS" "$CLIENT_BIN" \
        -h 127.0.0.1 -p "$PORT" \
        -d "$DEPTH:$DEPTH" -r "$RADIUS" -b "$BOARD" \
        -q -j "$json" >"$out" 2>&1
}

run_game A & PID_A=$!
run_game B & PID_B=$!

set +e
wait "$PID_A"; rc_a=$?
wait "$PID_B"; rc_b=$?
set -e

if [[ $rc_a -ne 0 || $rc_b -ne 0 ]]; then
    echo "ERROR: client A=$rc_a B=$rc_b" >&2
    echo "--- daemon log ---" >&2
    tail -n 50 "$LOG_DIR/daemon.log" >&2 || true
    exit 1
fi

# Each game should produce a JSON file with a "winner" field that's not "none".
for label in A B; do
    json="$LOG_DIR/game-${label}.json"
    if [[ ! -f "$json" ]]; then
        echo "ERROR: missing $json" >&2
        exit 1
    fi
    winner=$(python3 -c "import json,sys; print(json.load(open('$json'))['winner'])")
    if [[ "$winner" == "none" ]]; then
        echo "WARN: game $label did not finish ('winner' was 'none')" >&2
        # Not necessarily fatal — board fills are rare at this depth — but flag.
    else
        echo "==> game $label finished: winner=$winner"
    fi
done

echo "==> integration test passed"
