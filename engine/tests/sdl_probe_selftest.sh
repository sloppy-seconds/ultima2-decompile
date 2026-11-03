#!/usr/bin/env bash
# sdl_probe_selftest.sh — controls for engine/tools/sdl_probe.sh.
#
# The probe decides whether a build links the SDL the release ships, so a wrong
# verdict is a build that looks fine and is not. Each case here is a fixture, not
# a live host, so it runs identically on a machine with no SDL installed at all —
# including the CI runner, which is exactly where the probe is most likely to be
# wrong and least likely to be noticed.
#
# Two cases are the ones that matter and they are deliberate controls on each
# other:
#   - path says sdl2-compat while the version says a real SDL2: the path must win.
#     Without this case, the path check could be dead code and the suite would
#     not notice.
#   - path is clean and only the version betrays the shim: that is the Fedora
#     layout, where /usr/bin/sdl2-config is a plain file. The version heuristic
#     has to catch what the path cannot see.

set -u

PROBE="${PROBE:-$(dirname "$0")/../tools/sdl_probe.sh}"
WORK="${WORK:-/var/tmp/u2-sdl-probe-selftest}"
fail=0

ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fail=$((fail+1)); }

[ -f "$PROBE" ] || { echo "sdl_probe_selftest: no probe at $PROBE"; exit 1; }

rm -rf "$WORK"; mkdir -p "$WORK"

# --- fixtures ---------------------------------------------------------------
# A prefix holding a static lib: the release shape.
mkdir -p "$WORK/static/lib"
: > "$WORK/static/lib/libSDL2.a"

# sdl2-compat installed the way brew does it: a symlink into a directory that
# names the project. The version it reports is deliberately a REAL SDL2 version,
# so a probe that only looked at the number would call this genuine.
mkdir -p "$WORK/Cellar/sdl2-compat/2.32.74/bin"
cat > "$WORK/Cellar/sdl2-compat/2.32.74/bin/sdl2-config.real" <<'EOF'
#!/bin/sh
case "$1" in
  --version) echo 2.32.8 ;;
  --cflags)  echo -I/fake ;;
  --libs)    echo -lfake ;;
esac
EOF
chmod +x "$WORK/Cellar/sdl2-compat/2.32.74/bin/sdl2-config.real"
ln -s sdl2-config.real "$WORK/Cellar/sdl2-compat/2.32.74/bin/sdl2-config"

# The Fedora shape: a plain /usr/bin-style path with no hint in it, and a
# version number only sdl2-compat would use.
mkdir -p "$WORK/fedora/bin"
cat > "$WORK/fedora/bin/sdl2-config" <<'EOF'
#!/bin/sh
case "$1" in
  --version) echo 2.32.74 ;;
  --cflags)  echo -I/fake ;;
  --libs)    echo -lfake ;;
esac
EOF
chmod +x "$WORK/fedora/bin/sdl2-config"

# A genuine host SDL2, shared: acceptable for development, not the artifact.
mkdir -p "$WORK/real/bin"
sed 's/2\.32\.74/2.32.8/' "$WORK/fedora/bin/sdl2-config" > "$WORK/real/bin/sdl2-config"
chmod +x "$WORK/real/bin/sdl2-config"

# --- runner -----------------------------------------------------------------
# check <what> <want-exit> <want-substring> <probe args...>
check() {
    local what="$1" want_rc="$2" want="$3"; shift 3
    local out rc=0
    out=$(bash "$PROBE" "$@" --quiet 2>/dev/null) || rc=$?
    if [ "$rc" -ne "$want_rc" ]; then
        bad "$what: exit $rc, wanted $want_rc"
    elif [ -n "$want" ] && ! printf '%s\n' "$out" | grep -qF "$want"; then
        bad "$what: no '$want' in: $(printf '%s' "$out" | tr '\n' ' ')"
    elif [ -z "$want" ] && [ -n "$out" ]; then
        bad "$what: wanted no output, got: $(printf '%s' "$out" | tr '\n' ' ')"
    else
        ok "$what"
    fi
}

check "static prefix wins and is marked release" 0 "artifact=release" \
      --prefix "$WORK/static" --sdl2-config "$WORK/real/bin/sdl2-config"
check "static prefix reports static linkage"     0 "linkage=static" \
      --prefix "$WORK/static" --sdl2-config "$WORK/real/bin/sdl2-config"

check "path names sdl2-compat and beats a real-looking version" 0 "impl=sdl2-compat" \
      --prefix "$WORK/nope" --sdl2-config "$WORK/Cellar/sdl2-compat/2.32.74/bin/sdl2-config"
check "  ...and says the path is what decided it"               0 "impl_evidence=path" \
      --prefix "$WORK/nope" --sdl2-config "$WORK/Cellar/sdl2-compat/2.32.74/bin/sdl2-config"

check "clean path, compat version: caught by the number" 0 "impl=sdl2-compat" \
      --prefix "$WORK/nope" --sdl2-config "$WORK/fedora/bin/sdl2-config"
check "  ...and says the version is what decided it"     0 "impl_evidence=version" \
      --prefix "$WORK/nope" --sdl2-config "$WORK/fedora/bin/sdl2-config"

check "genuine shared SDL2 is dev, not release" 0 "artifact=dev" \
      --prefix "$WORK/nope" --sdl2-config "$WORK/real/bin/sdl2-config"
check "genuine shared SDL2 is still impl=sdl2"  0 "impl=sdl2" \
      --prefix "$WORK/nope" --sdl2-config "$WORK/real/bin/sdl2-config"

check "--strict refuses the shim" 4 "impl=sdl2-compat" \
      --prefix "$WORK/nope" --sdl2-config "$WORK/fedora/bin/sdl2-config" --strict
check "--strict does not refuse a static prefix" 0 "mode=static" \
      --prefix "$WORK/static" --sdl2-config "$WORK/fedora/bin/sdl2-config" --strict

check "nothing installed is mode=none" 3 "mode=none" \
      --prefix "$WORK/nope" --sdl2-config "$WORK/nope/sdl2-config"

check "a bad argument is a usage error" 2 "" --nope

printf '\n'
if [ "$fail" -eq 0 ]; then
    printf 'SDL PROBE: PASS\n'
else
    printf 'SDL PROBE: FAIL (%d)\n' "$fail"
fi
exit "$fail"
