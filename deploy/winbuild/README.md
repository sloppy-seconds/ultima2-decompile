# winbuild — cross-compile the Windows engine build

`./build.sh` produces `engine/u2-sdl.exe`: a single Windows x86_64 binary with
SDL2 statically linked, built entirely inside a container so nothing touches
the Bazzite host.

* The image (`Containerfile`) installs mingw-w64 and builds SDL2 from the
  pinned official release tarball — Fedora 42 dropped `mingw64-sdl2`, and the
  `sdl2-compat` replacement is shared-only, which defeats the static link.
* The Makefile target it runs is `make -C engine sdl-win`; with the toolchain
  installed natively you can run that directly instead.
* Verify a build: `file engine/u2-sdl.exe` (PE32+) and
  `podman run --rm -v $PWD/../..:/src:Z u2-winbuild x86_64-w64-mingw32-objdump -p /src/engine/u2-sdl.exe | grep "DLL Name"`
  — the list must contain only stock Windows DLLs.

## What "a working build" means here, and what it does not

This README described a green build before one had ever been observed on CI, and
the first CI run found a link failure the container had been hiding: mingw-w64
*declares* `clock_gettime` and `nanosleep`, so `time_posix.c` compiled clean, and
then the msvcrt it links against had no such symbols. The clock is now a
per-platform backend (`src/platform/time_win32.c`, selected by `WIN_SRCS`), and
as of 2026-11-02 the exe links and imports only stock DLLs — KERNEL32, USER32,
GDI32, WINMM, msvcrt and friends, no SDL2.dll and no libwinpthread-1.dll.

What is still **not** evidenced: the Windows binary has never been executed. There
is no wine here and no Windows runner, so `time_win32.c`'s tick maths and
`Sleep()` behaviour are inferred from the API, not observed. Anyone who runs
`u2-sdl.exe` and reports what the screen did has proved something this repo
cannot.

macOS is not cross-compiled from Linux (Apple SDK); that build is a CI
macos-runner job, deferred by the owner 2026-11-02.
