#!/usr/bin/env bash
# Build and start the Spice86-over-noVNC container on ai: the ORIGINAL game, in one
# container, watched from a browser.
#
#   ./up.sh                 # build if needed, start, print the URL
#   ./up.sh --rebuild       # force an image rebuild
#   ./up.sh --down          # stop and remove the container
#   ./up.sh --player FILE   # seed a saved character (then press P in the game)
#   ./up.sh --no-player     # start at the title with nothing to load
#   ./up.sh --no-patch      # leave arrow keys unpatched (use the numpad)
#   ./up.sh --name LABEL    # container name (default u2-spice86)
#
# Runs ROOTLESS (`podman`, no sudo), like every other project container on this host.
# Root's store and the rootless store are separate: an image built once with `sudo podman`
# is invisible here, so the first rootless run rebuilds it. That is the correct outcome, not
# a bug to paper over — see docs/phase4-state.md, "TODO: VNC desktop container for remote
# watching", constraint 1.
set -euo pipefail

IMAGE=u2-spice86-novnc
CONTAINER=u2-spice86
RUNS_HOST=/var/tmp/u2/spice86-runs
HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$HERE/../.." && pwd)

PLAYER=""
NO_PLAYER=0
NO_PATCH=0
REBUILD=0
DOWN=0

while [ $# -gt 0 ]; do
    case "$1" in
        --rebuild)   REBUILD=1; shift ;;
        --down)      DOWN=1; shift ;;
        --player)    PLAYER=$2; shift 2 ;;
        --no-player) NO_PLAYER=1; shift ;;
        --no-patch)  NO_PATCH=1; shift ;;
        --name)      CONTAINER=$2; shift 2 ;;
        -h|--help)   sed -n '2,12p' "$0"; exit 0 ;;
        *) echo "unknown option: $1" >&2; exit 2 ;;
    esac
done

if [ "$DOWN" = 1 ]; then
    podman rm -f "$CONTAINER" >/dev/null 2>&1 && echo "stopped $CONTAINER" || echo "no $CONTAINER"
    exit 0
fi

if [ "$REBUILD" = 1 ] || ! podman image exists "$IMAGE"; then
    echo "building $IMAGE (context is the project root; first build pulls ~250 MB) ..."
    # -f with the context at the repo root, so COPY can reach tools/patch_arrows.py.
    # .dockerignore is what keeps the GPL build and the game files out of the context.
    podman build -t "$IMAGE" -f "$HERE/Containerfile" "$ROOT"
else
    echo "reusing image $IMAGE (use --rebuild to refresh)"
fi

# --- ports -----------------------------------------------------------------
# Fixed, so the URL is the same every time: noVNC on 6085 (6080 belongs to `fmt`, 6081 to
# the engine container). Host networking, so the emulator's HTTP/MCP/GDB ports are
# reachable from the host and the existing tools (spice86_screenshot.py, spice86_type.py)
# drive the containerised emulator without a second implementation.
#
# Those three are the same numbers tools/spice86_start.sh uses, which means a host-side
# run and this container cannot be up at the same time. That is stated rather than papered
# over: the check below fails with the offending port instead of silently moving to a
# different one and leaving a stale bookmark in a browser.
NOVNC_PORT=${NOVNC_PORT:-6085}
VNC_PORT=${VNC_PORT:-5905}
HTTP_PORT=${HTTP_PORT:-20180}
MCP_PORT=${MCP_PORT:-20181}
GDB_PORT=${GDB_PORT:-20190}

port_busy() {
    # A port is busy when something answers a TCP connect. Bash's /dev/tcp avoids spawning
    # a helper, and a successful connect is unambiguous.
    (exec 3<>"/dev/tcp/127.0.0.1/$1") 2>/dev/null
}

# Tear the previous instance down BEFORE checking ports: a container holding 6085 is the
# most common thing that will be holding 6085, and checking first means every restart fails
# against itself. That is exactly what the first version of this script did.
podman rm -f "$CONTAINER" >/dev/null 2>&1 || true
sleep 1

for p in "$NOVNC_PORT" "$HTTP_PORT" "$MCP_PORT" "$GDB_PORT"; do
    if port_busy "$p"; then
        echo "port $p is already in use — stop whatever holds it, or override:" >&2
        echo "  NOVNC_PORT=6086 HTTP_PORT=... MCP_PORT=... GDB_PORT=... $0" >&2
        exit 1
    fi
done

mkdir -p "$RUNS_HOST"
ENV_ARGS=(
    --env "NOVNC_PORT=$NOVNC_PORT"
    --env "VNC_PORT=$VNC_PORT"
    --env "HTTP_PORT=$HTTP_PORT"
    --env "MCP_PORT=$MCP_PORT"
    --env "GDB_PORT=$GDB_PORT"
    --env "PATCH_ARROWS=$([ "$NO_PATCH" = 1 ] && echo 0 || echo 1)"
)
# --- character seed ----------------------------------------------------------
# The pristine references/ultima2/player is the 384-byte BLANK the game uses for
# *creation*. Pressing P with it answers "no character on disk!", which is exactly what
# happened on the first run of this container: it came up playable-looking and unplayable.
# So a real saved character is seeded by default, from a canonical copy kept in the runs
# dir (outside git, like every other save).
SEED_HOST="$RUNS_HOST/seed-player"
SEED_CONTAINER=/project/tmp/runs/seed-player

if [ "$NO_PLAYER" = 1 ]; then
    echo "no seed: 'P' at the title will say 'no character on disk!'"
elif [ -n "$PLAYER" ]; then
    [ -f "$PLAYER" ] || { echo "no such player file: $PLAYER" >&2; exit 1; }
    cp -- "$PLAYER" "$SEED_HOST"
    ENV_ARGS+=(--env "PLAYER_FILE=$SEED_CONTAINER")
    echo "seeding from $PLAYER -> $(python3 "$ROOT/tools/u2_edit.py" show "$PLAYER" 2>/dev/null | head -1)"
elif [ -f "$SEED_HOST" ]; then
    ENV_ARGS+=(--env "PLAYER_FILE=$SEED_CONTAINER")
    echo "seeding default character: $(python3 "$ROOT/tools/u2_edit.py" show "$SEED_HOST" 2>/dev/null | head -1)"
else
    echo "warning: no seed at $SEED_HOST and no --player; 'P' will say 'no character on disk!'" >&2
fi

echo "starting $CONTAINER ..."
# :z / :ro,z — SELinux. Without the label the container starts, Spice86 starts, and the
# only trace is a permission denied inside it (deploy/novnc/README.md trap #1).
podman run -d --name "$CONTAINER" \
    --network host \
    "${ENV_ARGS[@]}" \
    -v "$ROOT/tools/spice86:/opt/spice86:ro,z" \
    -v "$ROOT/references/ultima2:/content:ro,z" \
    -v "$RUNS_HOST:/project/tmp/runs:z" \
    "$IMAGE"

sleep 12
echo
echo "--- status ---"
podman ps --filter name="$CONTAINER" --format '{{.Names}}  {{.Status}}'
podman logs "$CONTAINER" 2>&1 | tail -14
echo
# Scaling is in the URL on purpose. Xvfb is 1440x900 and the Spice86 window is 1024x768
# placed at (208,66), so noVNC's default (scaling off) shows the desktop 1:1 and the browser
# pane crops the bottom of it -- which reads as "the game's status lines are missing" and is
# nothing of the sort. resize=scale fits the whole desktop to the pane; autoconnect skips the
# connect dialog. Found the hard way 2026-10-29.
echo "Open in a browser:   http://ai.lan:${NOVNC_PORT}/vnc.html?resize=scale&autoconnect=true"
echo "No password. If the page asks, click Skip/Continue."
echo
echo "Drive it from the host:"
echo "  python3 tools/spice86_screenshot.py /var/tmp/u2.png --mcp-port ${MCP_PORT}"
echo "  python3 tools/spice86_type.py --keys Escape,p --mcp-port ${MCP_PORT}"
echo "Logs:   podman logs -f ${CONTAINER}"
echo "Stop:   ${HERE}/up.sh --down"
