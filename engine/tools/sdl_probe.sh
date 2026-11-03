#!/usr/bin/env bash
# sdl_probe.sh — decide which SDL a build should link, and say what it found.
#
# Why this is a script and not four lines of Makefile: the decision has to be
# testable, and a `$(shell ...)` buried in a Makefile cannot be exercised against
# a fixture. The failure this exists to prevent is silent and plausible — a build
# against the wrong SDL implementation compiles, runs, and is not the artifact the
# release ships. That is worse than a build that fails, because a failing build is
# never mistaken for a passing one.
#
# Since the SDL3 port (docs/sdl2-vs-sdl3.md § 9) the project builds against SDL3.
# SDL2 is no longer an option, so the probe's job changed from "is this host SDL2
# really sdl2-compat" to "is there an SDL3 at all, and is it the pinned static one".
# A host that has only SDL2 now gets a clear refusal rather than a surprise, because
# the failure mode of the old behaviour was a build that looked fine.
#
# Output is key=value on stdout, one per line, so the Makefile can read it and a
# test can grep it. Diagnostics go to stderr. Exit status:
#   0  a usable SDL3 was found (mode=static or mode=dynamic)
#   3  no usable SDL3 (mode=none)
#   4  only a host/shared SDL3 was found and --strict was given
#
# Keys:
#   mode      static | dynamic | none
#   impl      sdl3 | none
#   impl_evidence  prefix | pkg-config | none   (how the choice was made)
#   version   the SDL3 version reported, or empty
#   linkage   static | dynamic | none
#   artifact  release | dev | none             (release == what CI would ship)
#   note      free text, empty or a warning meant for a human

set -u

PREFIX="${SDLSTAT_PREFIX:-/opt/sdl3-linux}"
PKG_CONFIG="${PKG_CONFIG:-pkg-config}"
SDL2_CONFIG="${SDL2_CONFIG:-sdl2-config}"
STRICT=0
QUIET=0

usage() {
    sed -n '2,32p' "$0" | sed 's/^# \{0,1\}//'
}

while [ $# -gt 0 ]; do
    case "$1" in
        --prefix)      PREFIX="$2"; shift 2 ;;
        --pkg-config)  PKG_CONFIG="$2"; shift 2 ;;
        --sdl2-config) SDL2_CONFIG="$2"; shift 2 ;;
        --strict)      STRICT=1; shift ;;
        --quiet)       QUIET=1; shift ;;
        -h|--help)     usage; exit 0 ;;
        *) echo "sdl_probe: unknown argument: $1" >&2; exit 2 ;;
    esac
done

note() { [ "$QUIET" -eq 1 ] || printf '%s\n' "$*" >&2; }

emit() {
    printf 'mode=%s\nimpl=%s\nimpl_evidence=%s\nversion=%s\nlinkage=%s\nartifact=%s\nnote=%s\n' \
        "$1" "$2" "$3" "$4" "$5" "$6" "$7"
}

find_static_lib() {
    local p
    for p in "$1/lib/libSDL3.a" "$1/lib64/libSDL3.a" "$1/lib/x86_64-linux-gnu/libSDL3.a"; do
        [ -f "$p" ] && { printf '%s\n' "$p"; return 0; }
    done
    return 1
}

# --- 1. a static prefix is the release shape, so it wins outright ------------
if static_lib=$(find_static_lib "$PREFIX"); then
    emit static sdl3 prefix "" static release ""
    exit 0
fi

# --- 2. a shared SDL3 from the host ------------------------------------------
if command -v "$PKG_CONFIG" >/dev/null 2>&1 && "$PKG_CONFIG" --exists sdl3 2>/dev/null; then
    ver=$("$PKG_CONFIG" --modversion sdl3 2>/dev/null | tr -d '[:space:]')
    warn="host SDL3 $ver is shared, not the pinned static SDL3 the release links. Fine for development; not the shipped artifact."
    emit dynamic sdl3 pkg-config "$ver" dynamic dev "$warn"
    note "sdl_probe: note — $warn"
    if [ "$STRICT" -eq 1 ]; then
        note "sdl_probe: REFUSING (--strict): a release build needs the static prefix at $PREFIX"
        exit 4
    fi
    exit 0
fi

# --- 3. nothing usable. Say what IS there, because "no SDL" is a wasted
#        afternoon if the machine actually has the wrong major version. --------
legacy=""
if command -v "$SDL2_CONFIG" >/dev/null 2>&1; then
    legacy=" SDL2 ($("$SDL2_CONFIG" --version 2>/dev/null)) is installed, but this project builds against SDL3 only — see docs/sdl2-vs-sdl3.md."
fi
emit none none none "" none none "$legacy"
note "sdl_probe: no SDL3 found."
note "           Looked for a static libSDL3.a under $PREFIX and for 'pkg-config sdl3'."
note "           If SDL3 is installed somewhere pkg-config cannot see (brew keeps it"
note "           under its own lib/pkgconfig), export PKG_CONFIG_PATH to include it."
[ -n "$legacy" ] && note "          $legacy"
note "           For the release artifact: deploy/linuxbuild/build.sh"
exit 3
