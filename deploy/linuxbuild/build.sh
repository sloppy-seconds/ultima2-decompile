#!/usr/bin/env bash
# build.sh — build engine/u2-sdl-static: the single-file Linux player binary
# (static SDL3, dynamic glibc) inside the linuxbuild container.
#
#   ./build.sh            # build the image if needed, then u2-sdl-static
#   ./build.sh --rebuild  # force-rebuild the image first
#
# Verify after: ldd engine/u2-sdl-static should show only libc/libm/libdl/
# libpthread (+ a couple of always-present system libs) — no libSDL3.so.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$HERE/../.." && pwd)"
IMAGE=u2-linuxbuild

[ "${1:-}" = "--rebuild" ] && BUILD_FLAG=(--no-cache) || BUILD_FLAG=()

if [ ${#BUILD_FLAG[@]} -gt 0 ] || ! podman image exists "$IMAGE"; then
    echo "linuxbuild: building image $IMAGE (one-off, cached after)"
    podman build "${BUILD_FLAG[@]}" -t "$IMAGE" -f "$HERE/Containerfile" "$HERE"
fi

podman run --rm -v "$REPO":/src:Z "$IMAGE" \
    make -C /src/engine sdl-static

# The gate, run against the artifact rather than the build log. A player binary
# whose only video drivers are `dummy` and `offscreen` cannot open a window on
# any desktop, and every other check passes on it: it links, it is static, ldd is
# clean. That is how the first release of this binary shipped headless-only.
echo "linuxbuild: video drivers compiled into the artifact:"
if ! drivers=$(podman run --rm -v "$REPO":/src:Z "$IMAGE" /src/engine/u2-sdl-static --video-drivers); then
    echo "linuxbuild: FAIL — the binary would not even list its drivers" >&2
    exit 1
fi
printf '%s\n' "$drivers" | sed 's/^/  /'
if ! printf '%s\n' "$drivers" | grep -qx -e x11 -e wayland; then
    echo "linuxbuild: FAIL — no display backend (need x11 or wayland)." >&2
    echo "  SDL3 was configured without the X11/Wayland dev packages; see Containerfile." >&2
    exit 1
fi

echo "linuxbuild: wrote engine/u2-sdl-static"
