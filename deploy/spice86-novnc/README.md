# u2-spice86-novnc — the original game, in a container, in a browser

Ultima II under Spice86, running windowed on a virtual X display inside podman, streamed
over noVNC. One container: Xvfb + Spice86 + x11vnc + websockify. This is the **original
binary**, not the Phase 4 engine; `deploy/novnc/` is the engine's equivalent and this file
deliberately mirrors its shape so the two are recognisably the same thing pointed at
different binaries.

Complements `tools/vnc/`, which is display-only: there, Spice86 runs on the host and only
the screen is containerised. Here the emulator is inside too, so the whole thing is one
command and the CFG dump lands on the host filesystem instead of in a container nobody
remembers to check.

## Run it

```sh
cd /var/home/paul/Projects/decompile-u2-v2
./deploy/spice86-novnc/up.sh            # builds on first run, then starts
```

Then open **http://ai.lan:6085/vnc.html**, click into the canvas, and press `P` twice to
load the seeded character. No password.

```sh
./deploy/spice86-novnc/up.sh --player tmp/<run>/player   # seed a different character
./deploy/spice86-novnc/up.sh --no-player                # title screen, nothing to load
./deploy/spice86-novnc/up.sh --no-patch                 # numpad 8/2/4/6 instead of arrow keys
./deploy/spice86-novnc/up.sh --rebuild                  # refresh the image
./deploy/spice86-novnc/up.sh --down                     # stop and remove
```

Keyboard works, so this is play and not watching: `D` demonstration, `C` create a
character, `E` enter a town, arrows walk (patched), `Q` saves.

## Which character

`up.sh` seeds a saved character by default and prints its name. Without one, `P` at the
title answers **"no character on disk!"**, because the pristine `references/ultima2/player`
is the 384-byte blank the game uses for *creation*, not a character. That is what happened
on this container's first run: it looked playable and was not.

The default seed is `/var/tmp/u2/spice86-runs/seed-player`, currently the project's test
character `G23MAX` (all stats 40, HP/gold/EXP 9999, sector 20 at 20,20), copied from
`tmp/20261023-204438/player`. It lives outside git like every other save.

Arrow keys are patched into the run copy by default (`tools/patch_arrows.py`, the same tool
and the same bytes as `--patch-arrows` in `spice86_start.sh`: file `0x5185` `3c007548` ->
`3c009090`). Verified end to end on this container rather than inferred from the window:
`Up` moved the character 20,20 -> 20,19 and `Right` to 21,19, read back over the HTTP API
with `s86_snapshot_ds`. `Down` did not move it, which is terrain at that tile, not a dead
key: `Left` from the same spot worked.

One quirk that is not a bug here: the **first key after launch is eaten by the title
splash**, so `P` has to be pressed twice. The host's `--auto-play` sends `Escape,p` for
exactly this reason.

The emulator's own API ports are published on the host network too, so the existing
capture tools drive this run without a second implementation:

```sh
python3 tools/spice86_screenshot.py /var/tmp/u2.png --mcp-port 20181
python3 tools/spice86_type.py --keys Escape,p --mcp-port 20181
```

## What is and is not in the image

The image carries the display plumbing and nothing else. **No game content and no emulator
build**, per the licensing rules in `AGENTS.md`: the game files are copyrighted and the
vendored Spice86 is GPL, so both are bind-mounted at run time and neither is ever baked in
or committed.

| mount | host path | mode | why |
| --- | --- | --- | --- |
| `/opt/spice86` | `tools/spice86/` | ro | the GPL, locally-patched emulator build |
| `/content` | `references/ultima2/` | ro | the pristine game files, copied from, never written |
| `/project/tmp/runs` | `/var/tmp/u2/spice86-runs/` | rw | run copies and CFG dumps, on disk, on the host |

`entrypoint.sh` copies `/content` into `/project/tmp/runs/<stamp>/` before launching,
because the game rewrites its own `player` file and is never run in place. That directory
is also where `dump/` goes, so a run that exits cleanly leaves its harvest behind on the
host.

`/var/tmp` and not `/tmp`: on this host `/tmp` is tmpfs and a big dump there takes RAM from
the running model.

## Eight things that cost time, in the order they bit

1. **No dotnet in the image.** `tools/spice86/` is a *self-contained* linux-x64 publish: it
   carries `libcoreclr.so`, `libhostfxr.so` and `libhostpolicy.so`, so the apphost runs
   standalone and installing a .NET runtime is 200 MB of waste. Verified before writing the
   Containerfile: `./tools/spice86/Spice86 --help` exits 0 with no `dotnet` in the picture.
2. **The apphost's interpreter path is a linuxbrew path.** `PT_INTERP` is
   `/home/linuxbrew/.linuxbrew/lib/ld.so`, which does not exist in a stock image, and the
   failure is the confusing kind: `No such file or directory` for a file that plainly
   exists, because the kernel is reporting the missing *interpreter*. The fix is one symlink
   in the image, which leaves the GPL binary unmodified:
   `ln -sf /lib64/ld-linux-x86-64.so.2 /home/linuxbrew/.linuxbrew/lib/ld.so`.
3. **`libicu` is not optional.** Without it the process `FailFast()`s at startup: an abort
   with a core dump, no window, and the reason only in stdout, reached from
   Spectre.Console's argument parser through `ToUpperInvariant`. This is the failure mode
   where the container looks alive and the emulator never existed.
4. **The bundled SDL2 hides its real dependencies.** `ldd` on `libSDL2-2.0.so` shows only
   libc/libm/libdl/libpthread, because Silk.NET's NuGet copy dlopens X11 at runtime. So the
   X client libraries have to be listed by hand, and a missing one surfaces as an SDL init
   failure rather than a loader error.
5. **Input focus, with no window manager.** `xdotool windowactivate` fails outright
   ("Your windowmanager claims not to support `_NET_ACTIVE_WINDOW`"), and with no focus set
   a key sent over X is swallowed silently: the send succeeds and the screen does not move.
   `xdotool windowfocus --sync <win>` is what works, and the entrypoint runs it once the
   window appears. Measured both ways: unfocused `key d` did nothing, focused `key d` went
   straight into the demonstration.
6. **`patch_arrows.py` refuses paths outside its project root**, and that guard is worth
   keeping rather than working around. So the container mirrors the layout: the tool is
   copied to `/project/tools/` and run dirs live under `/project/tmp/runs/`.

Also inherited from the engine container and still true: Xvfb must be 24-bit (8-bit reads as
"Palettized video modes are no longer supported"), and the display must be at least as large
as the window (Spice86's is 1024x768; the geometry is 1440x900). A too-small display crops
the picture and reports nothing.

7. **The pristine `player` file is not a character.** It is the blank creation template, so a
   container that mounts `references/ultima2/` unchanged comes up looking fine and says "no
   character on disk!" the moment anyone tries to play. See "Which character" above.
8. **The title splash eats the first key.** A single `P` does nothing and looks like a dead
   input path; it is the splash, not the keyboard.

## Ports

Fixed, so the bookmark never changes: **6085** noVNC (6080 belongs to `fmt`, 6081 to the
engine container), 5905 VNC, and 20180/20181/20190 for the HTTP/MCP/GDB APIs.

`up.sh` checks the ports and refuses rather than sliding to a different number, which is
what would leave a stale bookmark. It removes any previous instance *before* checking,
because a container holding 6085 is the most common thing holding 6085; the first version
checked first and so could never restart itself.

The API ports are the same numbers `tools/spice86_start.sh` uses, so a host-side run and
this container cannot be up at the same time. That is a deliberate trade for one URL and
one set of tool invocations.

## Exposure

Published on `0.0.0.0:6085` with **no VNC password**, the owner's standing call for this
box on a trusted LAN (recorded the same way in `deploy/novnc/README.md`). `x11vnc` still
runs with `-localhost`, so the raw VNC port is reachable only inside the container's
network namespace and adding a password later is a one-flag change, not a re-plumb.

The HTTP/MCP API is a different matter and is worth naming: MCP can **write** emulator
memory and inject keys, and on `--network host` it is exposed to the LAN without auth.
That is the same trust boundary as the game itself being playable by anyone on the LAN. If
this host ever leaves a trusted network, the API ports are the ones to pull first.

## Known gaps

- **A hard stop loses the dump.** `up.sh --down` and `podman stop` send SIGTERM, which
  Spice86 ignores (measured in headless mode; windowed mode's clean exit is closing the
  window from inside the GUI). The CFG dump is written on a clean exit only. For a live
  harvest, `monitor dumpAll` over the published GDB port is the route, and
  `tools/spice86_start.sh --harvest` cannot do it here because it reads the host's
  `tmp/.spice86-session.env` and signals a host pid.
- No audio. `SDL_AUDIODRIVER=dummy`; the container has no sound server. Silent by choice,
  not broken by accident.
- No window manager, so the emulator window cannot be moved or resized. It does not need
  to be at 1440x900.
- `--seed-map` has an env hook in `entrypoint.sh` (`SEED_MAP`) but no `up.sh` flag.
- Nothing here is wired into `make test`, and nothing in `make test` may come to depend on
  it: this container exists for a human with a browser.
