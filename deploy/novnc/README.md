# u2-novnc — play the engine in a browser, on `ai`

The engine's SDL build running headless in a podman container, streamed over noVNC.
This is how a person without a local display plays the reconstruction. Watching the
original through Spice86 is a separate, already-working setup
(`docs/phase4-state.md` § "TODO: VNC desktop container for remote watching"); this is
the same shape pointed at our own binary.

## Run it

```sh
cd /var/home/paul/Projects/decompile-u2-v2
make -C engine sdl                                  # the binary is built on the host
cp engine/u2-sdl deploy/novnc/u2-sdl
podman build -t u2-novnc:latest deploy/novnc/

mkdir -p /var/tmp/u2/novnc-saves
cp /var/tmp/u2/saves/tiles.u2tl /var/tmp/u2/novnc-saves/
cp original/player /var/tmp/u2/novnc-saves/PLAYER
tools/u2_edit.py set /var/tmp/u2/novnc-saves/PLAYER sector 20
tools/u2_edit.py setpos /var/tmp/u2/novnc-saves/PLAYER 20 20

podman run -d --name u2-novnc \
  -p 6081:6081 \
  -v "$PWD/original:/content:ro,z" \
  -v /var/tmp/u2/novnc-saves:/saves:z \
  u2-novnc:latest

# then, from anything on the LAN:
#   http://ai.lan:6081/vnc.html
```

Keyboard from the browser reaches the game, so this is play, not watching: arrow keys
walk, `A` + a direction attacks, `E` enters a town, `Q` saves, `ESC` leaves.

## Five things that cost time, in the order they bit

1. **SELinux.** Without `:z` on the bind mounts the container starts, the engine
   starts, and the only trace is `ls: cannot open directory '/content': Permission
   denied` inside it. The failure looks like a missing file, not a denied one, and
   the engine's own message ("no executable and no cached tiles") points at the
   wrong thing entirely.
2. **Xvfb must be 24-bit.** `320x200x8` — which is what you reach for when the game is
   four colours — makes SDL2's X11 backend refuse the visual with
   `Palettized video modes are no longer supported`, and the engine reports it as
   `backend initialisation failed`. The display depth has nothing to do with the
   game's palette; the engine composes a 32-bit RGBA surface and applies the CGA
   palette itself.
3. **The tiles cache is validated against the executable's digest**, and it lives in
   the *save* directory (`<save-dir>/tiles.u2tl`), not the content directory. Mount
   both, and put the cache with the save.
4. **Ports.** 6080 and 5900 belong to the Spice86 watching container, so this one
   defaults to 6081/5901 on display `:98`. Override with `-e NOVNC_PORT= -e
   VNC_PORT= -e DISPLAY=` if you run a second one.
6. **`podman restart` needs the X lock gone.** A restart reuses the container's
   writable layer, `/tmp/.X98-lock` survives, and Xvfb dies with the fatal
   `Server is already active for display 98` — the container looks quiet, not broken.
   `entrypoint.sh` removes its own display's lock before starting Xvfb.

**Where you start.** Sector 20 at (20,20) is the game's own starting map:
`engine/src/game/creation.c` sets `entry_x = entry_y = 20`, `sector_first = 2` citing
bytes `0x5BDC..0x5BE8`, and `DS:4A` is never written by creation so the second digit
stays 0. The container's `PLAYER` is built from the pristine `original/player` plus
those two edits rather than from a test character parked in a town.

5. **Xvfb must be at least as big as the SDL window**, which is `U2_SCREEN_W/H *
   SDL_SCALE` = **640x400**, not the 320x200 the game draws into. Setting the display
   to the native resolution — which is what you would guess — shows the top-left
   quarter of the game and nothing anywhere reports it: no error, no warning, just a
   cropped picture. If `SDL_SCALE` in `renderer_sdl.c` changes, `GEOMETRY` changes
   with it.

## Exposure, and why it is the way it is

Published on `0.0.0.0:6081` with **no VNC password**. That is the owner's call, made
on 2026-10-27 — *"it's just our LAN, it's secure, no need for a password"* — and it is
recorded here so nobody re-litigates it or, worse, half-applies it: the earlier
draft of this file bound loopback and required an SSH tunnel, and the difference
matters if this host ever stops being on a trusted network.

One layer is still there and is not just decoration: `x11vnc` runs with `-localhost`,
so the raw VNC port (5901) is reachable only from inside the container's network
namespace and never from the LAN. What is exposed is the noVNC web socket on 6081,
which is the same thing either way, but it means adding a password later is a
one-flag change in `entrypoint.sh` and not a re-plumb.

Audio is deliberately silent: the container has no sound server, `audio_sdl` fails to
load `libjack.so.0`, and the engine continues without it and says so. That is the
choice the TODO asked for made explicitly — silent by default, not broken by default.

## What is and is not in the image

The image carries the engine binary, SDL2, Xvfb, x11vnc, novnc and websockify. **No
game content.** `original/` is mounted read-only at `/content` and the save directory
read-write at `/saves`, per the licensing rules in `AGENTS.md`. The binary is copied
in rather than compiled in the image so that what runs is what the host's
`make -C engine test` actually tested.

## Known gaps

- The engine exits when the player presses `ESC`, and the entrypoint then tears down
  Xvfb and the container stops. Restart it to play again. A long-lived service would
  want a quadlet `.container` with `Restart=on-failure`, and the TODO in
  `docs/phase4-state.md` says so too; this is deliberately a run-it-when-you-want-to-
  play thing until the game has an ending worth resuming.
- `--play-map` skips the title and character creation. Drop `U2_ARGS` to
  `--sdl` for the full flow.
- Nothing here is wired into `make test`, and nothing in `make test` may come to
  depend on it: the CP4 dummy-driver assertion already covers the SDL pixel path for
  CI, and this container exists for a human with a browser.
