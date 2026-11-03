#!/usr/bin/env bash
# build.sh — cross-build engine/u2-sdl.exe (static SDL, Windows x86_64) inside
# the winbuild container. No host layering: everything lives in the image.
#
#   ./build.sh            # build the image if the Containerfile changed, then build
#   ./build.sh --rebuild  # force-rebuild the image first
#
# The exe lands in engine/ (bind-mounted), gitignored like every build output.
# Verify after: file engine/u2-sdl.exe  (PE32+ executable) and
#   x86_64-w64-mingw32-objdump -p engine/u2-sdl.exe | grep "DLL Name"
# should list only stock Windows DLLs — no SDL3.dll, no libwinpthread-1.dll.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$HERE/../.." && pwd)"
IMAGE=u2-winbuild

# shellcheck source=../image_fresh.sh
. "$HERE/../image_fresh.sh"

[ "${1:-}" = "--rebuild" ] && BUILD_FLAG=(--no-cache) || BUILD_FLAG=()

# Content-hash freshness, not "does an image exist": see ../image_fresh.sh. An
# edited Containerfile must never be silently ignored in favour of a stale image.
if [ ${#BUILD_FLAG[@]} -gt 0 ]; then
    u2_image_build "$IMAGE" "$HERE/Containerfile" --no-cache
else
    u2_image_build "$IMAGE" "$HERE/Containerfile"
fi

podman run --rm -v "$REPO":/src:Z "$IMAGE" \
    make -C /src/engine sdl-win

echo "winbuild: wrote engine/u2-sdl.exe"
