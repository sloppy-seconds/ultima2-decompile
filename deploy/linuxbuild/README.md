# linuxbuild — the static-SDL Linux player binary

`./build.sh` produces `engine/u2-sdl-static`: one file a real player downloads
and runs, no container, no package installs. The container here is only the
build host — Bazzite stays untouched and the SDL2 static build is reproducible.

* SDL2 is built from the pinned official tarball (same version and flags as
  winbuild's mingw build), linked static into the engine.
* glibc stays dynamic deliberately; a static glibc breaks NSS/dns/etc. and buys
  nothing here.
* **The X11/Wayland/audio `-devel` packages in the Containerfile are load-bearing,
  not garnish.** SDL's cmake silently compiles out any backend whose headers are
  missing, so an image without them produces a `libsdl2.a` containing only
  `dummy` and `offscreen`: a player binary that links, passes an `ldd` check, and
  cannot open a window on any desktop. That is what the first releases shipped,
  and nothing in the pipeline noticed until someone ran it on a real Wayland
  session. `SDL_*_SHARED` only removes the *runtime* dependency; the backend still
  has to be configured in at build time.
* `build.sh` therefore ends by asking the artifact what it can do —
  `u2-sdl-static --video-drivers` — and fails if neither `x11` nor `wayland` is
  listed. `release-builds.yml` runs the same check, and its SDL2 cache key is
  bumped to v2 because the old cached archive was the headless one.
* The game data model is unchanged: the player supplies their own `original/`
  copy (`--data-dir`, defaulting to the current directory), and the cleanroom
  tile art is compiled in.

Makefile target: `make sdl-static` (works natively with `SDLSTAT_PREFIX`
pointed at any prefix containing libsdl2.a).

`./build.sh --rebuild` forces a fresh image with `--no-cache`. It used to pass
`--build`, which `podman build` does not accept, so `--rebuild` had never worked;
winbuild had the same typo.
