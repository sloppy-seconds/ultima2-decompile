# winbuild — cross-compile the Windows engine build

`./build.sh` produces `engine/u2-sdl.exe`: a single Windows x86_64 binary with
SDL3 statically linked, built entirely inside a container so nothing touches
the Bazzite host.

* The image (`Containerfile`) installs mingw-w64 and builds SDL3 from the
  pinned official release tarball. Pinning is the point: a distro package moves
  under a cache key, and a release artifact has to be reproducible from a version
  number. (The original reason this image built SDL from source — Fedora 42
  dropping `mingw64-sdl2` in favour of a shared-only `sdl2-compat` — stopped
  applying when the engine moved to SDL3.)
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
GDI32, WINMM, msvcrt and friends, no SDL3.dll and no libwinpthread-1.dll.

What it has since been shown to do: the owner ran `u2-sdl.exe` **under wine on
Bazzite Linux** (2026-11-02) and it started, created a character, played the
overworld, entered a town and fought — and it loaded a `PLAYER` record written by
the Linux build. That is the first observation of `time_win32.c` doing anything
other than linking, and the first evidence of save portability between two engine
binaries rather than between the engine and the original.

What wine does **not** prove: real Windows driver behaviour. Wine implements the
Win32 API, not the graphics and audio stack underneath it, so a real GPU path, a
real sound device, and real filesystem semantics are still untested. Treat "runs
under wine" as strong evidence the engine is portable and not as a Windows
compatibility sign-off.

macOS is not cross-compiled from Linux (Apple SDK); that build is a CI
macos-runner job, deferred by the owner 2026-11-02.
