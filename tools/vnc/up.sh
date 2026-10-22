#!/usr/bin/env bash
# Build and start the VNC display container on ai. No password (LAN console).
#
#   ./up.sh              # build (if needed) and start
#   ./up.sh --rebuild    # force an image rebuild
#   ./up.sh --down       # stop and remove
set -euo pipefail

IMAGE=u2vnc-display
CONTAINER=u2vnc
HERE=$(cd "$(dirname "$0")" && pwd)

if [ "${1:-}" = "--down" ]; then
    sudo -n podman rm -f "$CONTAINER" && echo "stopped"
    exit 0
fi

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
    "$IMAGE"

sleep 8
echo
echo "--- status ---"
sudo -n podman ps --filter name="$CONTAINER" --format '{{.Names}}  {{.Status}}'
sudo -n podman logs "$CONTAINER" 2>&1 | tail -4
echo
echo "Open in a browser:   http://ai.lan:6080/vnc.html"
echo "No password. If the page asks for one, click Skip/Continue."
echo
echo "Then launch the emulator into this display from the host:"
echo "  DISPLAY=127.0.0.1:99 tools/spice86_start.sh --patch-arrows --player tmp/seed/player"
