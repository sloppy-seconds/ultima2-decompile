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

macOS is not cross-compiled from Linux (Apple SDK); that build is a CI
macos-runner job, deferred by the owner 2026-11-02.
