#!/usr/bin/env bash
# sdl_probe_selftest.sh — controls for engine/tools/sdl_probe.sh.
#
# The probe decides which SDL a build links, so a wrong verdict is a build that
# compiles, runs, and is not the artifact the release ships. Every case here is a
# fixture rather than a live host, so it runs identically on a machine with no SDL
# installed at all — including the CI runner, which is exactly where the probe is
# most likely to be wrong and least likely to be noticed.
#
# The case that earns its place is "SDL2 present, SDL3 absent": after the SDL3 port
# that machine cannot build a window binary at all, and a probe that just said "no
# SDL" would send someone off to install SDL2 again. The note is the test.

set -u

PROBE="${PROBE:-$(dirname "$0")/../tools/sdl_probe.sh}"
WORK="${WORK:-/var/tmp/u2-sdl-probe-selftest}"
fail=0

ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fail=$((fail+1)); }

[ -f "$PROBE" ] || { echo "sdl_probe_selftest: no probe at $PROBE"; exit 1; }

rm -rf "$WORK"; mkdir -p "$WORK"

# --- fixtures ---------------------------------------------------------------
mkdir -p "$WORK/static/lib"
: > "$WORK/static/lib/libSDL3.a"

# A pkg-config that claims an SDL3 is installed, shared.
cat > "$WORK/pkg-sdl3" <<'EOF'
#!/bin/sh
case "$1" in
  --exists)     exit 0 ;;
  --modversion) echo 3.4.18 ;;
  --cflags)     echo -I/fake/include/SDL3 ;;
  --libs)       echo -L/fake/lib -lSDL3 ;;
esac
EOF
chmod +x "$WORK/pkg-sdl3"

# A pkg-config that has never heard of SDL3 (the real one on a Fedora box with
# only sdl2-compat installed behaves exactly like this for our purposes).
cat > "$WORK/pkg-nosdl3" <<'EOF'
#!/bin/sh
case "$1" in
  --exists)     exit 1 ;;
  --modversion) echo "" ;;
esac
EOF
chmod +x "$WORK/pkg-nosdl3"

# An SDL2 on PATH, for the "wrong major version" note.
mkdir -p "$WORK/has-sdl2/bin"
cat > "$WORK/has-sdl2/bin/sdl2-config" <<'EOF'
#!/bin/sh
[ "$1" = --version ] && echo 2.32.8
EOF
chmod +x "$WORK/has-sdl2/bin/sdl2-config"

# --- runner -----------------------------------------------------------------
# check <what> <want-exit> <want-substring> <probe args...>
check() {
    local what="$1" want_rc="$2" want="$3"; shift 3
    local out rc=0
    out=$(bash "$PROBE" "$@" --quiet 2>&1) || rc=$?
    if [ "$rc" -ne "$want_rc" ]; then
        bad "$what: exit $rc, wanted $want_rc"
    elif [ -n "$want" ] && ! grep -qF "$want" <<< "$out"; then
        bad "$what: no '$want' in: $(printf '%s' "$out" | tr '\n' ' ')"
    elif [ -z "$want" ] && [ -n "$out" ]; then
        bad "$what: wanted no output, got: $(printf '%s' "$out" | tr '\n' ' ')"
    else
        ok "$what"
    fi
}

check "static prefix wins and is marked release" 0 "artifact=release" \
      --prefix "$WORK/static" --pkg-config "$WORK/pkg-nosdl3"
check "static prefix reports static linkage"     0 "linkage=static" \
      --prefix "$WORK/static" --pkg-config "$WORK/pkg-nosdl3"
check "static prefix names its evidence"         0 "impl_evidence=prefix" \
      --prefix "$WORK/static" --pkg-config "$WORK/pkg-nosdl3"

check "shared host SDL3 is dynamic"        0 "mode=dynamic" \
      --prefix "$WORK/nope" --pkg-config "$WORK/pkg-sdl3"
check "shared host SDL3 is impl=sdl3"      0 "impl=sdl3" \
      --prefix "$WORK/nope" --pkg-config "$WORK/pkg-sdl3"
check "shared host SDL3 is dev, not release" 0 "artifact=dev" \
      --prefix "$WORK/nope" --pkg-config "$WORK/pkg-sdl3"
check "shared host SDL3 carries its version" 0 "version=3.4.18" \
      --prefix "$WORK/nope" --pkg-config "$WORK/pkg-sdl3"

check "--strict refuses a shared SDL3" 4 "artifact=dev" \
      --prefix "$WORK/nope" --pkg-config "$WORK/pkg-sdl3" --strict
check "--strict accepts a static prefix" 0 "mode=static" \
      --prefix "$WORK/static" --pkg-config "$WORK/pkg-sdl3" --strict

check "no SDL3 at all is mode=none" 3 "mode=none" \
      --prefix "$WORK/nope" --pkg-config "$WORK/pkg-nosdl3" \
      --sdl2-config "$WORK/nope/sdl2-config"

# The one that would otherwise cost someone an afternoon: SDL2 is installed, so a
# generic "no SDL" message sends them to install SDL2 again.
check "SDL2-installed-but-no-SDL3 says so" 3 "SDL2" \
      --prefix "$WORK/nope" --pkg-config "$WORK/pkg-nosdl3" \
      --sdl2-config "$WORK/has-sdl2/bin/sdl2-config"

check "a bad argument is a usage error" 2 "unknown argument" --nope

printf '\n'
if [ "$fail" -eq 0 ]; then
    printf 'SDL PROBE: PASS\n'
else
    printf 'SDL PROBE: FAIL (%d)\n' "$fail"
fi
exit "$fail"
