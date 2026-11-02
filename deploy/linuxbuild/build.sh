#!/usr/bin/env bash
# build.sh — build engine/u2-sdl-static: the single-file Linux player binary
# (static SDL2, dynamic glibc) inside the linuxbuild container.
#
#   ./build.sh            # build the image if needed, then u2-sdl-static
#   ./build.sh --rebuild  # force-rebuild the image first
#
# Verify after: ldd engine/u2-sdl-static should show only libc/libm/libdl/
# libpthread (+ a couple of always-present system libs) — no libsdl2.so.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$HERE/../.." && pwd)"
IMAGE=u2-linuxbuild

[ "${1:-}" = "--rebuild" ] && BUILD_FLAG=(--build) || BUILD_FLAG=()

if [ ${#BUILD_FLAG[@]} -gt 0 ] || ! podman image exists "$IMAGE"; then
    echo "linuxbuild: building image $IMAGE (one-off, cached after)"
    podman build "${BUILD_FLAG[@]}" -t "$IMAGE" -f "$HERE/Containerfile" "$HERE"
fi

podman run --rm -v "$REPO":/src:Z "$IMAGE" \
    make -C /src/engine sdl-static

echo "linuxbuild: wrote engine/u2-sdl-static"
