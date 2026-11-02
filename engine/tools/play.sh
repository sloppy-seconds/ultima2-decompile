#!/bin/sh
# play.sh — put the game on the operator's screen.
#
# Why this exists: the agent shell that drives this repo has no DISPLAY and no
# WAYLAND_DISPLAY in its environment (it is not a graphical login session), so a
# plain `./u2-sdl` — which now defaults to the window — fails at SDL init and
# draws nothing anyone can see. The display has to be synthesised from the socket
# files, which is what tools/spice86_common.sh already does for the emulator; this
# is the same trick, kept in one place so it is not tribal knowledge.
#
# Usage:
#   tools/play.sh                 player's own extracted art
#   tools/play.sh --cleanroom     compiled-in substitute art
#   tools/play.sh --sector 22     start in sector 22 (two digits)
#
# Any unrecognised argument is passed straight to the engine, so this stays a
# launcher and not a second configuration system.

set -e
cd "$(dirname "$0")/.." || exit 1

# --- display, synthesised from the sockets that actually exist ---------------
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
if [ -z "${WAYLAND_DISPLAY:-}" ] && [ -S "$XDG_RUNTIME_DIR/wayland-0" ]; then
    WAYLAND_DISPLAY=wayland-0
    export WAYLAND_DISPLAY
fi
if [ -z "${DISPLAY:-}" ] && [ -S /tmp/.X11-unix/X0 ]; then
    DISPLAY=:0
    export DISPLAY
fi
# xauth, if the session left one behind; without it X connections can be refused.
if [ -z "${XAUTHORITY:-}" ]; then
    xa=$(ls "$XDG_RUNTIME_DIR"/xauth_* 2>/dev/null | head -1) || true
    [ -n "$xa" ] && export XAUTHORITY="$xa"
fi

if [ -z "${WAYLAND_DISPLAY:-}" ] && [ -z "${DISPLAY:-}" ]; then
    echo "play: no Wayland socket at $XDG_RUNTIME_DIR/wayland-0 and no X socket" \
         "at /tmp/.X11-unix/X0." >&2
    echo "play: there is no graphical session to draw into; nothing was launched." >&2
    exit 1
fi

# --- build the SDL binary if it is missing or stale --------------------------
if [ ! -x u2-sdl ] || [ -n "$(find src -newer u2-sdl -name '*.c' -print -quit 2>/dev/null)" ]; then
    echo "play: building the SDL target"
    make -s sdl
fi

ARGS="--sdl --play-map --data-dir ../original --save-dir saves"
for a in "$@"; do
    case "$a" in
        --cleanroom) ARGS="$ARGS --cleanroom" ;;
        *)           ARGS="$ARGS $a" ;;
    esac
done

echo "play: WAYLAND_DISPLAY=${WAYLAND_DISPLAY:-unset} DISPLAY=${DISPLAY:-unset}"
echo "play: ./u2-sdl $ARGS"
# shellcheck disable=SC2086
exec ./u2-sdl $ARGS
