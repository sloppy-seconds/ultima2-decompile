# linuxbuild — the static-SDL Linux player binary

`./build.sh` produces `engine/u2-sdl-static`: one file a real player downloads
and runs, no container, no package installs. The container here is only the
build host — Bazzite stays untouched and the SDL2 static build is reproducible.

* SDL2 is built from the pinned official tarball (same version and flags as
  winbuild's mingw build), linked static into the engine.
* glibc stays dynamic deliberately; a static glibc breaks NSS/dns/etc. and buys
  nothing here.
* SDL dlopens X11/Wayland/ALSA at runtime, so the binary needs only what every
  desktop already ships.
* The game data model is unchanged: the player supplies their own `original/`
  copy (`--data-dir`), and the cleanroom tile art is compiled in.

Makefile target: `make sdl-static` (works natively with `SDLSTAT_PREFIX`
pointed at any prefix containing libsdl2.a).
