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

# --- the tile extractor ---------------------------------------------------
# The art is game content and is never committed, so it has to arrive from the
# player's own executable at run time. The synthetic-image half of this test
# always runs and proves the assertions reject a wrong layout; the real-binary
# half SKIPs when no copy is here, so CI stays green and honest.
cc -std=c11 -Wall -Wextra -Werror -Isrc -o "$WORK/tiles_check" \
   tests/tiles_check.c src/core/tiles.c src/core/sha256.c 2>"$WORK/cc-tiles.err"
if [ $? -ne 0 ]; then
    bad "tiles test harness did not build: $(head -5 "$WORK/cc-tiles.err")"
else
    REAL_EXE=""
    for c in ../original/ultimaii.exe ../original/ULTIMAII.EXE; do
        if [ -r "$c" ]; then REAL_EXE="$c"; break; fi
    done
    if "$WORK/tiles_check" "$WORK" "$REAL_EXE" > "$WORK/tiles.out" 2>&1; then
        n=$(grep -c '  ok  ' "$WORK/tiles.out")
        if [ -n "$REAL_EXE" ]; then
            ok "tile extractor: invariants, cache round-trip, real binary ($n checks)"
        else
            ok "tile extractor: invariants and cache round-trip ($n checks, real-binary SKIP)"
        fi
    else
        bad "tiles check failed:"
        sed 's/^/        /' "$WORK/tiles.out"
    fi
fi

# --- the viewport mapping -------------------------------------------------
# The viewport is where a map byte becomes something drawable, so the whole CP4
# render contract rests on these rules: geometry, the index formula, the
# off-sector fallback and the underlay suppression.
cc -std=c11 -Wall -Wextra -Werror -Isrc -o "$WORK/view_check" \
   tests/view_check.c src/core/view.c 2>"$WORK/cc-view.err"
if [ $? -ne 0 ]; then
    bad "viewport test harness did not build: $(head -5 "$WORK/cc-view.err")"
else
    if "$WORK/view_check" > "$WORK/view.out" 2>&1; then
        ok "viewport: geometry, index formula, off-sector, suppression ($(grep -c '  ok  ' "$WORK/view.out") checks)"
    else
        bad "viewport check failed:"
        sed 's/^/        /' "$WORK/view.out"
    fi
fi

# --- the framebuffer ------------------------------------------------------
# Every display backend sits behind this, so a mistake here reaches all of them.
cc -std=c11 -Wall -Wextra -Werror -Isrc -o "$WORK/frame_check" \
   tests/frame_check.c src/core/frame.c src/core/view.c 2>"$WORK/cc-frame.err"
if [ $? -ne 0 ]; then
    bad "framebuffer test harness did not build: $(head -5 "$WORK/cc-frame.err")"
else
    if "$WORK/frame_check" > "$WORK/frame.out" 2>&1; then
        ok "framebuffer: blit, clipping, compositing, PPM/BMP ($(grep -c '  ok  ' "$WORK/frame.out") checks)"
    else
        bad "framebuffer check failed:"
        sed 's/^/        /' "$WORK/frame.out"
    fi
fi

# --- the engine font -------------------------------------------------------
# CP4b: text in the framebuffer is drawn with the vendored public-domain
# 8x8 font, so every string screen (status band, menu, creation) rests on
# these glyph semantics.
cc -std=c11 -Wall -Wextra -Werror -Isrc -o "$WORK/font_check" \
   tests/font_check.c src/core/font.c src/core/frame.c src/core/view.c 2>"$WORK/cc-font.err"
if [ $? -ne 0 ]; then
    bad "font test harness did not build: $(head -5 "$WORK/cc-font.err")"
else
    if "$WORK/font_check" > "$WORK/font.out" 2>&1; then
        ok "engine font: glyphs, grid, clipping, determinism ($(grep -c '  ok  ' "$WORK/font.out") checks)"
    else
        bad "font check failed:"
        sed 's/^/        /' "$WORK/font.out"
    fi
fi

# --- the status band and the CMD message window ----------------------------
# CP4b task 1: the owner's model of the block — four rows, live prompt at the
# bottom, completed commands scrolling up, status block outside the scroll
# rect — as tested behaviour, not folklore.
cc -std=c11 -Wall -Wextra -Werror -Isrc -Ibuild -o "$WORK/status_check" \
   tests/status_check.c src/game/status.c src/core/seam.c src/core/vram.c \
   src/core/state.c src/core/font.c src/core/frame.c src/core/view.c \
   src/core/rng.c src/core/timer.c src/core/replay.c src/core/sha256.c \
   src/debug/trace.c src/debug/dump_state.c 2>"$WORK/cc-status.err"
if [ $? -ne 0 ]; then
    bad "status test harness did not build: $(head -5 "$WORK/cc-status.err")"
else
    if "$WORK/status_check" > "$WORK/status.out" 2>&1; then
        ok "status band + CMD window: BCD lines, prompt, scroll history ($(grep -c '  ok  ' "$WORK/status.out") checks)"
    else
        bad "status check failed:"
        sed 's/^/        /' "$WORK/status.out"
    fi
fi

# --- the Q save round trip --------------------------------------------------
# The owner's test: walk, Q saves the live position into the record, restart,
# P lands where the player stood. Plus the outdoors guard and the CP11
# save-anywhere policy hook.
cc -std=c11 -Wall -Wextra -Werror -Isrc -Ibuild -o "$WORK/save_q_check" \
   tests/save_q_check.c src/game/overworld.c src/game/status.c src/core/world.c \
   src/core/save.c src/core/tiles.c src/core/sha256.c src/core/seam.c \
   src/core/vram.c src/core/state.c src/core/font.c src/core/frame.c \
   src/core/view.c src/core/rng.c src/core/timer.c src/core/replay.c \
   src/debug/trace.c src/debug/dump_state.c 2>"$WORK/cc-saveq.err"
if [ $? -ne 0 ]; then
    bad "save-Q test harness did not build: $(head -5 "$WORK/cc-saveq.err")"
else
    if "$WORK/save_q_check" "$WORK/saveq" > "$WORK/saveq.out" 2>&1; then
        ok "Q save round trip: guards, dirty rule, policy hook, P restore ($(grep -c '  ok  ' "$WORK/saveq.out") checks)"
    else
        bad "save-Q check failed:"
        sed 's/^/        /' "$WORK/saveq.out"
    fi
fi

# --- time passes: the PASS action spends food, starvation kills -----------
# file 0x0B0D spends 10 food per PASS and file 0x0B2E sends a borrow to the
# death handler at runtime 0x0E62 (asm/0C62), which zeroes DS:51..59.
cc -std=c11 -Wall -Wextra -Werror -Isrc -Ibuild -o "$WORK/food_check" \
   tests/food_check.c src/game/overworld.c src/game/status.c src/core/world.c \
   src/core/save.c src/core/tiles.c src/core/sha256.c src/core/seam.c \
   src/core/vram.c src/core/state.c src/core/font.c src/core/frame.c \
   src/core/view.c src/core/rng.c src/core/timer.c src/core/replay.c \
   src/debug/trace.c src/debug/dump_state.c 2>"$WORK/cc-food.err"
if [ $? -ne 0 ]; then
    bad "food test harness did not build: $(head -5 "$WORK/cc-food.err")"
else
    if "$WORK/food_check" > "$WORK/food.out" 2>&1; then
        ok "food tick: PASS spends 10, underflow zeroes every stat ($(tail -1 "$WORK/food.out"))"
    else
        bad "food check failed:"
        sed 's/^/        /' "$WORK/food.out"
    fi
fi

# --- the map actually renders, when the player has their files ------------
# The point of the whole CP4 chain: sector + tiles + viewport + framebuffer
# producing real pixels. Skips without the content, so CI stays honest.
MAPDIR=""
for c in ../original ../original/updated; do
    if [ -r "$c/ultimaii.exe" ] && [ -r "$c/mapx30" ]; then MAPDIR="$c"; break; fi
done
if [ -n "$MAPDIR" ]; then
    if ./u2 --data-dir "$MAPDIR" --save-dir "$WORK/saves" \
            --dump-map "$WORK/map.ppm" >"$WORK/dump.err" 2>&1; then
        sz=$(wc -c < "$WORK/map.ppm" 2>/dev/null || echo 0)
        if [ "$sz" -eq 192015 ]; then
            ok "--dump-map renders the real sector to 320x200 pixels ($sz B)"
        else
            bad "--dump-map wrote $sz bytes, expected 192015 for a 320x200 PPM"
        fi
        # Second run must come from the cache the first run created.
        if grep -q 'tiles from cache' <(./u2 --data-dir "$MAPDIR" \
                --save-dir "$WORK/saves" --dump-map "$WORK/map2.ppm" 2>&1); then
            ok "second run serves tiles from the cache it bootstrapped"
            cmp -s "$WORK/map.ppm" "$WORK/map2.ppm" \
                && ok "cached and extracted frames are byte-identical" \
                || bad "cached frame differs from the extracted one"
        else
            bad "second run re-extracted: the cache did not bootstrap"
        fi
    else
        bad "--dump-map failed: $(tail -2 "$WORK/dump.err")"
    fi
else
    printf '  SKIP  no player content: --dump-map not exercised\n'
fi

# --- --data-dir is part of the documented contract ----------------------
./u2 --help 2>&1 | grep -q -- '--data-dir' \
    && ok "--data-dir is in the usage text" \
    || bad "--data-dir missing from usage"

# --- zero game content committed ----------------------------------------
# The whole point of the CP4 decision: the map never enters the repo, so the
# loader must carry no tile tables and no baked sector bytes.
if grep -qE '0x[0-9a-fA-F]{2},[[:space:]]*0x[0-9a-fA-F]{2},[[:space:]]*0x' src/core/world.c src/core/world.h src/core/tiles.c src/core/tiles.h; then
    bad "core/world.[ch] or core/tiles.[ch] contains an inline byte table — map and tile bytes must come from the player's files"
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

# --- the SDL path proves itself headlessly, when u2-sdl is built ----------
# Standing directive: the cell -> font -> upload chain must be testable without
# a display. SDL_VIDEODRIVER=dummy gives exactly that. It used to hang after
# writing the frame (T6: --dump-screen set dump_screen_done, the poll turned
# that into input_exhausted, and wait_choice only tested exit_code), so this
# test is also the regression guard for that. Skipped when the SDL build was
# not requested, because SDL2 is an owner-install dependency.
if [ -x ./u2-sdl ]; then
    rm -f "$WORK/sdl.ppm"
    SDL_VIDEODRIVER=dummy timeout -s KILL 20 ./u2-sdl --sdl --dump-screen "$WORK/sdl.ppm" \
        >/dev/null 2>&1
    sdl_rc=$?
    if [ "$sdl_rc" -ne 0 ]; then
        bad "headless SDL run did not exit cleanly (rc=$sdl_rc; a hang here is the T6 defect)"
    elif [ ! -s "$WORK/sdl.ppm" ]; then
        bad "headless SDL run wrote no frame"
    else
        ppm_size=$(wc -c < "$WORK/sdl.ppm" | tr -d ' ')
        [ "$ppm_size" = "192015" ] \
            && ok "headless SDL: dummy driver presents a 320x200 frame ($ppm_size B)" \
            || bad "headless SDL frame is $ppm_size B, expected 192015 (P6 320x200)"
        # Ink check: the title screen is text on black, so a presented frame
        # must contain non-black pixels. A blanked frame is the failure mode
        # this guards (the same class the screenshot diff guards for the map).
        ink=$(python3 - "$WORK/sdl.ppm" <<'PY'
import sys
raw = open(sys.argv[1], 'rb').read()
end = 0
for _ in range(3):                      # P6, dims, maxval
    end = raw.index(b'\n', end) + 1
px = raw[end:]
print(sum(1 for i in range(0, len(px), 3) if px[i:i+3] != b'\x00\x00\x00'))
PY
)
        [ -n "$ink" ] && [ "$ink" -gt 100 ] \
            && ok "headless SDL frame carries ink ($ink non-black pixels, not a blank upload)" \
            || bad "headless SDL frame is blank or unreadable (ink=$ink)"
    fi
else
    printf '  SKIP  u2-sdl not built (make sdl) — headless SDL path not exercised\n'
fi

printf '\n'
if [ "$fail" -eq 0 ]; then
    printf 'CP4 TEST: PASS\n'
else
    printf 'CP4 TEST: FAIL\n'
fi
exit "$fail"
