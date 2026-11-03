#!/usr/bin/env bash
# sdl_probe.sh — decide which SDL a build should link, and say what it found.
#
# Why this is a script and not four lines of Makefile: the decision has to be
# testable, and a `$(shell ...)` buried in a Makefile cannot be exercised against
# a fixture. The failure this exists to prevent is silent and plausible — on a
# Bazzite or Arch host, `sdl2-config` resolves to sdl2-compat, which implements
# the SDL2 API on top of SDL3. A build against it compiles, runs, and is not the
# artifact the release ships. That is worse than a build that fails, because a
# failing build is never mistaken for a passing one.
#
# Output is key=value on stdout, one per line, so the Makefile can eval it and a
# test can grep it. Diagnostics go to stderr. Exit status:
#   0  a usable SDL was found (mode=static or mode=dynamic)
#   3  no SDL at all (mode=none)
#   4  a host SDL was found but it is the compat shim and --strict was given
#
# Keys:
#   mode      static | dynamic | none
#   impl      sdl2 | sdl2-compat | unknown
#   impl_evidence  path | version | none      (how impl was decided)
#   version   the SDL2 API version reported, or empty
#   linkage   static | dynamic | none
#   artifact  release | dev | none           (release == what CI would ship)
#   note      free text, empty or a warning meant for a human

set -u

PREFIX="${SDLSTAT_PREFIX:-/opt/sdl2-linux}"
SDL2_CONFIG="${SDL2_CONFIG:-sdl2-config}"
STRICT=0
QUIET=0

usage() {
    sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//'
}

while [ $# -gt 0 ]; do
    case "$1" in
        --prefix)        PREFIX="$2"; shift 2 ;;
        --sdl2-config)   SDL2_CONFIG="$2"; shift 2 ;;
        --strict)        STRICT=1; shift ;;
        --quiet)         QUIET=1; shift ;;
        -h|--help)       usage; exit 0 ;;
        *) echo "sdl_probe: unknown argument: $1" >&2; exit 2 ;;
    esac
done

# Real SDL2 patch numbers on the 2.32 line are small and even (2.32.0 .. 2.32.10
# as of 2026-11-03). sdl2-compat versions itself in the same 2.32.x space but
# well above it (2.32.54 .. 2.32.74), because it tracks its own releases rather
# than SDL2's. The number alone is a heuristic; the path is proof. Keep the
# threshold as a named constant so a future real SDL2 that crosses it is a
# deliberate edit and not a mystery.
COMPAT_PATCH_MIN=40

note() { [ "$QUIET" -eq 1 ] || printf '%s\n' "$*" >&2; }

emit() {
    printf 'mode=%s\nimpl=%s\nimpl_evidence=%s\nversion=%s\nlinkage=%s\nartifact=%s\nnote=%s\n' \
        "$1" "$2" "$3" "$4" "$5" "$6" "$7"
}

find_static_lib() {
    local p
    for p in "$1/lib/libSDL2.a" "$1/lib64/libSDL2.a" "$1/lib/x86_64-linux-gnu/libSDL2.a"; do
        [ -f "$p" ] && { printf '%s\n' "$p"; return 0; }
    done
    return 1
}

# --- 1. a static prefix is the release shape, so it wins outright ------------
static_lib=""
if static_lib=$(find_static_lib "$PREFIX"); then
    emit static sdl2 path "" static release ""
    exit 0
fi

# --- 2. fall back to whatever the host offers -------------------------------
if ! command -v "$SDL2_CONFIG" >/dev/null 2>&1; then
    emit none unknown none "" none none ""
    note "sdl_probe: no static SDL2 at $PREFIX and no '$SDL2_CONFIG' on PATH."
    note "           Either run deploy/linuxbuild/build.sh, or install SDL2, or"
    note "           point SDLSTAT_PREFIX at a prefix containing lib/libSDL2.a."
    exit 3
fi

ver=$("$SDL2_CONFIG" --version 2>/dev/null | tr -d '[:space:]')
impl=unknown
evidence=none

# The path is the strong signal: distros and brew install the shim under a
# directory that says so, and resolving the symlink makes a wrapper honest.
cfg_path=$(readlink -f "$SDL2_CONFIG" 2>/dev/null || echo "$SDL2_CONFIG")
case "$cfg_path" in
    *sdl2-compat*|*sdl2_compat*) impl=sdl2-compat; evidence=path ;;
esac

# Version as the fallback when the path tells us nothing, e.g. a distro that
# installs the shim under a plain name.
if [ "$impl" = unknown ] && [ -n "$ver" ]; then
    patch=${ver##*.}
    case "$patch" in
        ''|*[!0-9]*) : ;;
        *) if [ "$patch" -ge "$COMPAT_PATCH_MIN" ] 2>/dev/null; then
               impl=sdl2-compat; evidence=version
           else
               impl=sdl2; evidence=version
           fi ;;
    esac
fi

warn=""
if [ "$impl" = sdl2-compat ]; then
    warn="host SDL2 is sdl2-compat (an SDL2 API layer over SDL3), not the SDL2 the release ships. This binary is a dev build and is NOT the artifact players download. For the real thing: deploy/linuxbuild/build.sh"
    emit dynamic "$impl" "$evidence" "$ver" dynamic dev "$warn"
    if [ "$STRICT" -eq 1 ]; then
        note "sdl_probe: REFUSING (--strict): $warn"
        exit 4
    fi
    note "sdl_probe: WARNING — $warn"
    exit 0
fi

# A genuine host SDL2, shared. Better than the shim, still not the release: the
# release pins a specific version and links it statically.
warn="host SDL2 $ver is shared, not the pinned static SDL2 the release links. Fine for development; not the shipped artifact."
emit dynamic sdl2 "$evidence" "$ver" dynamic dev "$warn"
note "sdl_probe: note — $warn"
exit 0
