#!/bin/sh
# Starts Xvfb + x11vnc + noVNC inside the display container.
#
# No VNC password: this is a LAN-only play/testing console, owner-requested
# 2026-10-22. The listener is therefore bound to the LAN on purpose. Do not put
# this on a routable network. Game content is never stored here.
set -eu

DISPLAY_NUM=${DISPLAY_NUM:-99}
GEOMETRY=${GEOMETRY:-1024x768x8}
VNC_PORT=${VNC_PORT:-5900}
NOVNC_PORT=${NOVNC_PORT:-6080}

Xvfb ":$DISPLAY_NUM" -screen 0 "$GEOMETRY" -listen tcp >/tmp/xvfb.log 2>&1 &
sleep 3

xhost +local: >/dev/null 2>&1 || true
xhost +localhost >/dev/null 2>&1 || true

x11vnc -display ":$DISPLAY_NUM" \
       -nopw \
       -rfbport "$VNC_PORT" \
       -forever -shared -noxdamage \
       >/tmp/x11vnc.log 2>&1 &
sleep 2

websockify "$NOVNC_PORT" "127.0.0.1:$VNC_PORT" --web=/usr/share/novnc/ >/tmp/novnc.log 2>&1 &

echo "display :$DISPLAY_NUM up on $GEOMETRY"
echo "vnc:    0.0.0.0:$VNC_PORT (no password)"
echo "noVNC:  http://<host>:$NOVNC_PORT/vnc.html"

wait
