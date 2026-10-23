#!/usr/bin/env bash
# Build and start the VNC display container on ai. No password (LAN console).
#
#   ./up.sh              # build (if needed) and start
#   ./up.sh --rebuild    # force an image rebuild
#   ./up.sh --down       # stop and remove
#
# Ports come from the environment and are forwarded to the container, which is what
# tools/vnc/start.sh actually reads: DISPLAY_NUM (99), VNC_PORT (5900), NOVNC_PORT
# (6080). They used to be hardcoded in the printed URL only, so with `fmt` holding host
# port 6080 websockify failed to bind, the script printed the URL as if it had worked,
# and the failure looked like a browser problem. It now refuses to start on a busy port
# and verifies the bind afterwards.
set -euo pipefail

IMAGE=u2vnc-display
CONTAINER=u2vnc
HERE=$(cd "$(dirname "$0")" && pwd)

DISPLAY_NUM=${DISPLAY_NUM:-99}
VNC_PORT=${VNC_PORT:-5900}
NOVNC_PORT=${NOVNC_PORT:-6080}

# The container runs --network host, so "is the port free" is a host question and has to
# be asked of the host before the run, not discovered afterwards from a log line.
port_busy() {
    ss -ltn "sport = :$1" 2>/dev/null | tail -n +2 | grep -q .
}

if [ "${1:-}" = "--down" ]; then
    sudo -n podman rm -f "$CONTAINER" >/dev/null 2>&1 && echo "stopped" || echo "nothing to stop"
    exit 0
fi

for p in "$NOVNC_PORT" "$VNC_PORT"; do
    if port_busy "$p"; then
        echo "REFUSING: host port $p is already listening." >&2
        echo "  $(ss -ltnp "sport = :$p" 2>/dev/null | tail -n +2 | head -1)" >&2
        echo "  Pick other ports, e.g.:  NOVNC_PORT=6081 VNC_PORT=5901 ./up.sh" >&2
        exit 1
    fi
done

if ! sudo -n podman info >/dev/null 2>&1; then
    echo "sudo podman needs a password. Run 'sudo -v' and retry." >&2
    exit 1
fi

if [ "${1:-}" = "--rebuild" ] || ! sudo -n podman image exists "$IMAGE"; then
    echo "building $IMAGE (first build installs packages, ~1-2 min) ..."
    sudo -n podman build -t "$IMAGE" "$HERE"
else
    echo "reusing image $IMAGE"
fi

echo "starting $CONTAINER ..."
sudo -n podman rm -f "$CONTAINER" >/dev/null 2>&1 || true
sudo -n podman run -d --name "$CONTAINER" \
    --network host \
    --env "GEOMETRY=${GEOMETRY:-1024x768x8}" \
    --env "DISPLAY_NUM=$DISPLAY_NUM" \
    --env "VNC_PORT=$VNC_PORT" \
    --env "NOVNC_PORT=$NOVNC_PORT" \
    "$IMAGE"

# Verify rather than assert. A container that is Up proves nothing on its own: websockify
# can fail to bind inside it and leave the container running and the page unreachable.
sleep 8
if ! port_busy "$NOVNC_PORT"; then
    echo "FAILED: nothing is listening on host port $NOVNC_PORT after 8s." >&2
    echo "  container status: $(sudo -n podman ps --filter name="$CONTAINER" --format '{{.Status}}')" >&2
    echo "  last log lines:" >&2
    sudo -n podman logs "$CONTAINER" 2>&1 | tail -6 >&2
    echo "  novnc log inside the container:" >&2
    sudo -n podman exec "$CONTAINER" tail -6 /tmp/novnc.log >&2 2>/dev/null || true
    exit 1
fi

echo
echo "--- status ---"
sudo -n podman ps --filter name="$CONTAINER" --format '{{.Names}}  {{.Status}}'
sudo -n podman logs "$CONTAINER" 2>&1 | tail -4
echo
echo "Open in a browser:   http://ai.lan:$NOVNC_PORT/vnc.html"
echo "No password. If the page asks for one, click Skip/Continue."
echo
echo "Then launch the emulator into this display from the host:"
echo "  DISPLAY=127.0.0.1:$DISPLAY_NUM tools/spice86_start.sh --patch-arrows --player tmp/seed/player"
