#!/usr/bin/env bash
# tests/run_cp4.sh — CP4 acceptance test: overworld + movement.
#
# The gate for CP4 is an owner playthrough ("walk around a map"). What can be
# proven mechanically first is the sector model: the map is runtime data read
# from the player's own files, so the loader has to get sizes, indexing, naming
# and write-back right without a single game byte in the repository.
set -uo pipefail

cd "$(dirname "$0")/.." || exit 1
fail=0
ok()  { printf '  PASS  %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fail=1; }

WORK=$(mktemp -d "${TMPDIR:-/var/tmp}/u2-cp4.XXXXXX")
trap 'rm -rf "$WORK"' EXIT

printf 'engine CP4 test\n'

# --- the sector loader ----------------------------------------------------
cc -std=c11 -Wall -Wextra -Werror -Isrc -o "$WORK/world_check" \
   tests/world_check.c src/core/world.c 2>"$WORK/cc.err"
if [ $? -ne 0 ]; then
    bad "world test harness did not build: $(head -5 "$WORK/cc.err")"
else
    "$WORK/world_check" "$WORK" > "$WORK/world.out" 2>&1 \
        && ok "sector model: sizes, indexing, naming, write-back ($(grep -c '  ok  ' "$WORK/world.out") checks)" \
        || { bad "world check failed:"; sed 's/^/        /' "$WORK/world.out"; }
fi

# --- --data-dir is part of the documented contract ----------------------
./u2 --help 2>&1 | grep -q -- '--data-dir' \
    && ok "--data-dir is in the usage text" \
    || bad "--data-dir missing from usage"

# --- zero game content committed ----------------------------------------
# The whole point of the CP4 decision: the map never enters the repo, so the
# loader must carry no tile tables and no baked sector bytes.
if grep -qE '0x[0-9a-fA-F]{2},[[:space:]]*0x[0-9a-fA-F]{2},[[:space:]]*0x' src/core/world.c src/core/world.h; then
    bad "core/world.[ch] contains an inline byte table — map bytes must come from the player's files"
else
    ok "no tile bytes baked into the sector model"
fi

if find . -path ./build -prune -o -name 'mapx*' -print -o -name 'monx*' -print | grep -q .; then
    bad "a mapx*/monx* file exists inside engine/ — world content must never be committed"
else
    ok "no world content files inside engine/"
fi

# --- the engine never invents a world ------------------------------------
GHOST="$WORK/ghost"
./u2 --headless --script tests/title.keys --data-dir "$GHOST" >/dev/null 2>&1
if [ -e "$GHOST" ]; then
    bad "a run created --data-dir $GHOST; the content directory is the player's, not ours to make"
else
    ok "a run with an absent --data-dir creates nothing"
fi

# --- the shipped content still loads, when the player has it -------------
CONTENT=""
for d in ../original ../references/ultima2; do
    [ -f "$d/mapx00" ] && CONTENT="$d" && break
done
if [ -n "$CONTENT" ]; then
    SIZE=$(wc -c < "$CONTENT/mapx00" | tr -d ' ')
    [ "$SIZE" = "4224" ] \
        && ok "player content found at $CONTENT (mapx00 is 4224 B: 4096 tiles + 128 tail)" \
        || bad "$CONTENT/mapx00 is $SIZE B, expected 4224 (4096 tiles + unread tail)"
    ./u2 --headless --script tests/title.keys --data-dir "$CONTENT" >/dev/null 2>&1 \
        && ok "a run against the player's own content directory exits clean" \
        || bad "run against $CONTENT failed"
else
    printf '  SKIP  no player content present (pass --data-dir to test against it)\n'
fi

printf '\n'
if [ "$fail" -eq 0 ]; then
    printf 'CP4 TEST: PASS\n'
else
    printf 'CP4 TEST: FAIL\n'
fi
exit "$fail"
