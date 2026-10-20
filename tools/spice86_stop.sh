#!/usr/bin/env bash
# spice86_stop.sh — stop the running Spice86 session cleanly, and harvest the
# CFG it produces.
#
# "Cleanly" is load-bearing, not politeness. Spice86 writes its runtime CFG
# (blocks, partitions, execution flow, memory dump) when it shuts down; a
# SIGKILL throws that away.
#
# Measured on this build (2026-10-21), headless mode: Spice86 ignores BOTH
# SIGTERM and SIGINT — it sat through each until SIGKILL. So in headless mode
# there is no signal that produces the exit dump, and the harvest cannot depend
# on one. That is why step 1 below is not an optimisation: `monitor dumpAll`
# over the GDB port is what actually guarantees the CFG is written. The signal
# sequence is teardown, not flush. In --watch (windowed) mode closing the window
# is a real clean exit and does dump on its own; the live dumpAll is harmless
# there and still runs first.
#
# Order of operations:
#   1. `monitor dumpAll` over the GDB port -> dump while alive (the guarantee).
#   2. SIGTERM the process group (the launcher used setsid, so children go too).
#   3. Wait a short while, then SIGKILL, and say so, because in headless mode
#      the wait is known to be wasted time.
#   4. Harvest whatever landed under the run dir into captures/spice86/<label>/
#      and print counts, so the operator sees evidence rather than filenames.
#   5. Confirm the ports are released; a stale bind is what makes the next
#      launch fail confusingly.

set -euo pipefail

# shellcheck source=spice86_common.sh
. "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/spice86_common.sh"

usage() {
    cat <<'EOF'
usage: spice86_stop.sh [options]

  --timeout SECS   how long to wait after SIGTERM before SIGKILL (default 8;
                   headless Spice86 ignores SIGTERM/SIGINT, so a long wait is
                   provably wasted time here)
  --no-harvest     stop only; leave the dump files in the run dir
  --keep-run       keep the scratch run directory (default: keep it too, this
                   flag exists to make the intent explicit in scripts)
  -h, --help       this text
EOF
}

TIMEOUT=8
HARVEST=1

while [ $# -gt 0 ]; do
    case "$1" in
        --timeout)    TIMEOUT=$2; shift 2 ;;
        --no-harvest) HARVEST=0; shift ;;
        --keep-run)   shift ;;
        -h|--help)    usage; exit 0 ;;
        *) echo "unknown option: $1" >&2; usage >&2; exit 2 ;;
    esac
done

s86_state_read || {
    echo "no session recorded at $(s86_state_file)" >&2
    echo "nothing to stop; start one with tools/spice86_start.sh" >&2
    exit 1
}

PID=${S86_PID:-}
PGID=${S86_PGID:-$PID}

if [ -z "$PID" ] || ! kill -0 "$PID" 2>/dev/null; then
    echo "recorded pid ${PID:-?} is not running; clearing stale state"
    # The dump may still exist from a previous crash-free exit; harvest it.
    if [ "$HARVEST" -eq 1 ] && [ -n "${S86_DUMP_DIR:-}" ] && [ -d "$S86_DUMP_DIR" ]; then
        if DEST=$(s86_harvest "$S86_DUMP_DIR" "${S86_LABEL:-unknown}"); then
            echo "harvested from the abandoned dump dir -> $DEST"
            s86_harvest_summary "$DEST"
        fi
    fi
    s86_state_clear
    exit 0
fi

echo "stopping pid=$PID pgid=$PGID label=${S86_LABEL:-?} (timeout ${TIMEOUT}s)"

# 1. force a dump while alive, best effort
if [ -n "${S86_GDB_PORT:-}" ] && command -v gdb >/dev/null 2>&1; then
    echo "  live dumpAll via gdb port ${S86_GDB_PORT} ... "
    s86_dumpall_live "$S86_GDB_PORT" >/dev/null 2>&1 \
        && echo "  live dumpAll        ok" \
        || echo "  live dumpAll        skipped (gdb port busy or closed)"
fi

# 2. ask politely
if kill -TERM -- "-${PGID}" 2>/dev/null; then
    echo "  SIGTERM -> process group $PGID"
else
    kill -TERM "$PID" 2>/dev/null && echo "  SIGTERM -> pid $PID" \
        || echo "  could not signal the process" >&2
fi

# 3. wait, then escalate
DEADLINE=$((SECONDS + TIMEOUT))
while [ $SECONDS -lt $DEADLINE ]; do
    kill -0 "$PID" 2>/dev/null || break
    sleep 0.5
done

KILLED=0
if kill -0 "$PID" 2>/dev/null; then
    KILLED=1
    echo "  still alive after ${TIMEOUT}s; escalating to SIGKILL" >&2
    echo "  (expected in headless mode: the CFG was already written by dumpAll)" >&2
    kill -KILL -- "-${PGID}" 2>/dev/null || kill -KILL "$PID" 2>/dev/null || true
    sleep 1
fi

if [ "$KILLED" -eq 0 ]; then
    echo "  exited cleanly"
fi

# 4. harvest. Search the run dir, not just the -r dir: Spice86 may still create
# a SHA-256-named sibling, and a harvest that silently misses it is worse than
# one that reports nothing.
DEST=""
HARVEST_ROOT="${S86_RUN_DIR:-${S86_DUMP_DIR:-}}"
if [ "$HARVEST" -eq 1 ] && [ -n "$HARVEST_ROOT" ] && [ -d "$HARVEST_ROOT" ]; then
    if DEST=$(s86_harvest "$HARVEST_ROOT" "${S86_LABEL:-unknown}"); then
        echo "harvest -> $DEST"
        s86_harvest_summary "$DEST"
    else
        echo "no CFG dump produced (searched: $HARVEST_ROOT)" >&2
    fi
fi

# 5. ports released?
for p in ${S86_HTTP_PORT:-} ${S86_MCP_PORT:-} ${S86_GDB_PORT:-}; do
    [ -n "$p" ] || continue
    if s86_port_free "$p"; then
        echo "  port $p released"
    else
        echo "  port $p STILL BOUND - a process is holding it" >&2
    fi
done

s86_state_clear
echo "done. run dir kept at ${S86_RUN_DIR:-?}"
