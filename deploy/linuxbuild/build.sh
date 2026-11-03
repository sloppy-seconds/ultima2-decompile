#!/usr/bin/env bash
# build.sh — build engine/u2-sdl-static: the single-file Linux player binary
# (static SDL3, dynamic glibc) inside the linuxbuild container.
#
#   ./build.sh            # build the image if the Containerfile changed, then build
#   ./build.sh --rebuild  # force a no-cache image rebuild first
#
# Verify after: ldd engine/u2-sdl-static should show only libc/libm/libdl/
# libpthread (+ a couple of always-present system libs) — no libSDL3.so.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$HERE/../.." && pwd)"
IMAGE=u2-linuxbuild

# shellcheck source=../image_fresh.sh
. "$HERE/../image_fresh.sh"

[ "${1:-}" = "--rebuild" ] && BUILD_FLAG=(--no-cache) || BUILD_FLAG=()

# Freshness is the Containerfile's content hash, stamped on the image at build
# time, not "does an image exist". The old test meant an edited Containerfile was
# silently ignored in favour of a stale image, which is how both SDL3 container
# builds reported "static SDL3 not found" while actually building SDL2.
if [ ${#BUILD_FLAG[@]} -gt 0 ]; then
    u2_image_build "$IMAGE" "$HERE/Containerfile" --no-cache
else
    u2_image_build "$IMAGE" "$HERE/Containerfile"
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
