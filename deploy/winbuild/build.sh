#!/usr/bin/env bash
# build.sh — cross-build engine/u2-sdl.exe (static SDL, Windows x86_64) inside
# the winbuild container. No host layering: everything lives in the image.
#
#   ./build.sh            # build the image if needed, then u2-sdl.exe
#   ./build.sh --rebuild  # force-rebuild the image first
#
# The exe lands in engine/ (bind-mounted), gitignored like every build output.
# Verify after: file engine/u2-sdl.exe  (PE32+ executable) and
#   x86_64-w64-mingw32-objdump -p engine/u2-sdl.exe | grep "DLL Name"
# should list only stock Windows DLLs — no SDL2.dll, no libwinpthread-1.dll.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$HERE/../.." && pwd)"
IMAGE=u2-winbuild

[ "${1:-}" = "--rebuild" ] && BUILD_FLAG=(--no-cache) || BUILD_FLAG=()

if [ ${#BUILD_FLAG[@]} -gt 0 ] || ! podman image exists "$IMAGE"; then
    echo "winbuild: building image $IMAGE (one-off, cached after)"
    podman build "${BUILD_FLAG[@]}" -t "$IMAGE" -f "$HERE/Containerfile" "$HERE"
fi

podman run --rm -v "$REPO":/src:Z "$IMAGE" \
    make -C /src/engine sdl-win

echo "winbuild: wrote engine/u2-sdl.exe"
