#!/bin/sh
# Xvfb + the engine + x11vnc + websockify, in one container.
#
# Deliberately a supervisor-free script: this is a person pointing a browser at a
# game, not a service with a restart policy. If the engine exits, everything exits,
# and podman reports the container as stopped, which is the honest signal.
set -eu

: "${DISPLAY:=:98}"
# Must be at least the SDL window, which is U2_SCREEN_W/H * SDL_SCALE = 640x400
# (renderer_sdl.c). A display smaller than the window does not clip or scroll — X
# places the window anyway and you see the top-left quarter of the game, with no
# error anywhere to say so. If SDL_SCALE changes, this changes with it.
: "${GEOMETRY:=640x400x24}"
: "${VNC_PORT:=5901}"
: "${NOVNC_PORT:=6081}"
: "${DATA_DIR:=/content}"
: "${SAVE_DIR:=/saves}"
: "${U2_ARGS:=--sdl --play-map}"

echo "novnc-engine: Xvfb on ${DISPLAY} at ${GEOMETRY}"
# Xvfb refuses to start on a display whose lock file survives: `Server is already
# active for display 98`, fatal, and the container looks merely quiet rather than
# broken. `podman restart` reuses the container's writable layer, so the lock from
# the previous run is still there. This is the container's own ephemeral /tmp, the
# lock belongs to the X server this script is about to start, and nothing else in
# this image uses display :98 — so removing it is correct, not cleanup.
rm -f "/tmp/.X${DISPLAY#*:}-lock" "/tmp/.X11-unix/X${DISPLAY#:}"
Xvfb "${DISPLAY}" -screen 0 "${GEOMETRY}" -nolisten tcp &
XVFB_PID=$!

# Xvfb takes a moment to own the socket; without this the engine falls back to the
# dummy driver or dies, and "it rendered nothing" is a miserable thing to debug.
# A fixed wait rather than an xdpyinfo poll: xdpyinfo is a separate package and the
# container has no reason to carry X client utilities just to answer "is the socket
# up yet". 2 s is generous for Xvfb on this host and the failure mode is a clean
# engine exit, not a silent blank screen.
sleep 2

echo "novnc-engine: u2-sdl ${U2_ARGS}"
# shellcheck disable=SC2086
export SDL_VIDEODRIVER=x11
u2-sdl ${U2_ARGS} --data-dir "${DATA_DIR}" --save-dir "${SAVE_DIR}" &
U2_PID=$!

# -forever so closing one browser tab does not end the session, -shared so two
# tabs work, and no -rfbauth: the port stays bound to loopback inside the
# container's network namespace and access is by SSH tunnel, not by password
# over a LAN. If it is ever exposed on 0.0.0.0, add -rfbauth and do not skip it.
x11vnc -display "${DISPLAY}" -forever -shared -localhost -rfbport "${VNC_PORT}" &
VNC_PID=$!

websockify --web=/usr/share/novnc "${NOVNC_PORT}" "localhost:${VNC_PORT}" &
WS_PID=$!

echo "novnc-engine: ready -> http://localhost:${NOVNC_PORT}/vnc.html"

# If the engine finishes (a scripted run, or the player quitting), tear everything
# down so the container exits instead of sitting on a dead X display.
wait "${U2_PID}"
STATUS=$?
echo "novnc-engine: engine exited (${STATUS}); shutting down"
kill "${WS_PID}" "${VNC_PID}" "${XVFB_PID}" 2>/dev/null || true
exit "${STATUS}"
