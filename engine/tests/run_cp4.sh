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

# --- the time doors -------------------------------------------------------
# The gate table, the two observed era pairings, and the rotation. The spec is written
# to reject invention: slots 0 and 3 have never been transited and must report unknown.
# Evidence: docs/moongates.md, captures/spice86/moongate-cycle.
cc -std=c11 -Wall -Wextra -Werror -Isrc -o "$WORK/gate_check" \
   tests/gate_check.c src/game/gates.c src/core/world.c src/core/state.c 2>"$WORK/cc-gate.err"
if [ $? -ne 0 ]; then
    bad "gate test harness did not build: $(head -5 "$WORK/cc-gate.err")"
else
    GATE_EXE=""
    for c in ../original/ultimaii.exe ../original/ULTIMAII.EXE; do
        if [ -r "$c" ]; then GATE_EXE="$c"; break; fi
    done
    "$WORK/gate_check" "$GATE_EXE" > "$WORK/gate.out" 2>&1 \
        && ok "time doors: table, pairings, rotation ($(grep -c '  ok  ' "$WORK/gate.out") checks)" \
        || { bad "gate check failed:"; sed 's/^/        /' "$WORK/gate.out"; }
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

# --- the generated cleanroom art ---------------------------------------------
# Two separate guarantees, because a generated file fails quietly. First the
# committed header must still match the SVGs it came from: hand-editing it, or
# changing the art and forgetting to regenerate, both leave a header that looks
# fine and ships stale bytes. Second the bytes must decode through the engine's
# own u2_tile_pixel() into the pixels the SVGs actually contain, which size
# assertions alone would not catch.
ART_SRC=assets/tiles/cleanroom/tiles
python3 tools/tiles2h.py --src "$ART_SRC" -o "$WORK/tiles_cleanroom.h" \
    >"$WORK/gen-art.out" 2>&1
if [ $? -ne 0 ]; then
    bad "cleanroom art generator failed: $(tail -3 "$WORK/gen-art.out")"
elif ! cmp -s "$WORK/tiles_cleanroom.h" src/core/tiles_cleanroom.h; then
    bad "src/core/tiles_cleanroom.h does not match the SVG sources. Regenerate:"
    echo "        (cd engine && python3 tools/tiles2h.py --src assets/tiles/cleanroom/tiles -o src/core/tiles_cleanroom.h)" >&2
    diff "$WORK/tiles_cleanroom.h" src/core/tiles_cleanroom.h | head -10 >&2
else
    ok "cleanroom art: committed header matches the SVG sources (no drift)"
fi

cc -std=c11 -Wall -Wextra -Werror -Isrc -o "$WORK/tiles_art_check" \
   tests/tiles_art_check.c src/core/tiles_builtin.c 2>"$WORK/cc-art.err"
if [ $? -ne 0 ]; then
    bad "cleanroom art harness did not build: $(head -5 "$WORK/cc-art.err")"
elif "$WORK/tiles_art_check" > "$WORK/art.out" 2>&1; then
    ok "cleanroom art: $(tail -1 "$WORK/art.out")"
else
    bad "cleanroom art check failed:"
    sed 's/^/        /' "$WORK/art.out"
fi

# --- the tile rules gate -------------------------------------------------------
# Structural conformance of the substitute art to the requirements the owner stated in
# docs/tile-art-spec.md § 7a: a ring must be hollow, a pass must be open at the bottom, a
# signpost must have one crossbar rather than two, a letter tile must carry its rules.
# Geometry the eye judges badly at 16x16 -- detached fragments that read as confetti, seams
# that break a repeating pattern -- is exactly what these checks are good at.
#
# This gate is NOT shown to whoever draws the art. Its bands were fitted to the originals, so
# reading it would be reading the answer key; see § 2 of the spec and PROVENANCE.md.
# Tiles awaiting a clean redraw are listed in PENDING_REDRAW and reported as visible debt
# rather than failure, so the suite is green now and goes red if a redraw breaks a rule that
# tile already passes. The pending list is hardcoded on purpose: deriving it from the art
# would let every failing tile classify itself as pending and make the gate vacuous.
if python3 ../tools/tile_rules.py --src "$ART_SRC" > "$WORK/rules.out" 2>&1; then
    ok "$(head -1 "$WORK/rules.out")"
    grep 'NOTE' "$WORK/rules.out" | sed 's/^/        /' || true
else
    bad "tile rules gate failed:"
    sed 's/^/        /' "$WORK/rules.out"
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
   tests/save_q_check.c src/game/overworld.c src/game/commands.c src/debug/turnlog.c src/game/ai.c src/game/combat.c src/game/monsters.c src/game/gates.c src/game/commerce.c src/core/tiles_builtin.c src/game/status.c src/core/world.c \
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
   tests/food_check.c src/game/overworld.c src/game/commands.c src/debug/turnlog.c src/game/ai.c src/game/combat.c src/game/monsters.c src/game/gates.c src/game/commerce.c src/core/tiles_builtin.c src/game/status.c src/core/world.c \
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

# --- G2: the per-step charge is inside the passability call, so refusals pay --
# asm/2599 and asm/2626 subtract 19 from the food triple ahead of the tile verdict
# inside asm/2423, so `--INVALID MOVE!` is not a free refusal. Measured 2026-10-25
# on the maxed seed in sector 31: one arrow into a blocked cell, DS:00/01 unchanged,
# food down exactly 19, screen `CMD: WEST--INVALID MOVE!`.
#
# The observable is death, not the FOOD digits: the band is only repainted at the
# sites asm/5129 is called from, so a quiet one-unit charge never reaches the
# screen. Thirteen food units and one step makes the charge itself observable — and
# it discriminates the amount, because the port once passed decimal 19 where the
# asm's immediate 0x19 was meant and charged thirteen, which survives.
for arm in water-poor grass-poor water-rich none-poor; do
    python3 tests/cp5_fight_seed.py "$WORK/g2-$arm" >/dev/null 2>&1
    python3 tests/g2_step_food.py "$WORK/g2-$arm" "$arm" >/dev/null 2>&1
    : > "$WORK/g2-$arm.keys"
    if [ "$arm" != "none-poor" ]; then
        printf '0xf2\n' > "$WORK/g2-$arm.keys"    # 0xf2 is U2_KEY_LEFT: step west
    fi
    ./u2 --headless --play-map --cleanroom \
         --data-dir "$WORK/g2-$arm/content" --save-dir "$WORK/g2-$arm/save" \
         --script "$WORK/g2-$arm.keys" --dump-state > "$WORK/g2-$arm.out" 2>&1
done
if grep -q "IS DEAD!" "$WORK/g2-water-poor.out"; then
    if grep -q "IS DEAD!" "$WORK/g2-grass-poor.out"; then
        if grep -q -- "WEST--INVALID MOVE!" "$WORK/g2-water-rich.out" \
           && ! grep -q "IS DEAD!" "$WORK/g2-water-rich.out"; then
            if grep -q "IS DEAD!" "$WORK/g2-none-poor.out"; then
                bad "CP4 G2 control: the no-input arm died — the gate cannot fail"
            else
                ok "step charge: an accepted and a refused step both cost 19 (13 units dies either way); the control survives"
            fi
        else
            bad "CP4 G2: the water arm did not read as a refused-but-surviving step — the reject path is not what the cost arms travelled"
            sed 's/^/        /' "$WORK/g2-water-rich.out" | tail -6
        fi
    else
        bad "CP4 G2: the accepted step did not kill on 13 food — the move charge is missing or under-sized"
    fi
else
    bad "CP4 G2: a refused step cost no food — asm/2423 charges ahead of the verdict and the engine must too"
    sed 's/^/        /' "$WORK/g2-water-poor.out" | tail -6
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

# --- the screenshot differential, when the evidence is on disk ------------
# Standing directive: validate the engine against the owner's play screenshots
# as a test. The screenshots are gitignored (derived from copyrighted art), so
# this SKIPs with a named reason when they or PIL are absent, and goes live
# the moment they are present. It compares the status-block region only; the
# map region differs by sector/position and is out of scope (see the tool's
# header). The engine frame is rendered here so both sides come from one run.
SHOT="../captures/screenshots/move-after.png"
if python3 -c "import PIL" 2>/dev/null && [ -f "$SHOT" ] && [ -x ./u2 ]; then
    ./u2 --headless --dump-map "$WORK/t7-engine.ppm" --data-dir "$CONTENT" \
        >/dev/null 2>&1 || true
    if [ ! -s "$WORK/t7-engine.ppm" ] && [ -z "$CONTENT" ]; then
        printf '  SKIP  no content dir for the engine frame in the screenshot diff\n'
    else
        if python3 ../tools/screenshot_diff.py --screenshot "$SHOT" \
               --engine-ppm "$WORK/t7-engine.ppm" >"$WORK/t7.out" 2>&1; then
            ok "screenshot diff: status block agrees with the play shot ($(grep agreement "$WORK/t7.out" | awk '{print $3}') ink on both sides)"
        else
            bad "screenshot diff failed:"
            sed 's/^/        /' "$WORK/t7.out"
        fi
    fi
else
    printf '  SKIP  screenshot diff not run (needs PIL + captures/screenshots/move-after.png)\n'
fi

# --- T5: the creation tail, under both fidelities -------------------------
# The original's tail (asm/5400) prints "TO PLAY ULTIMA II", then "INSERT
# PROGRAM MASTER", spins on key_poll and calls the program startup routine at
# runtime 0x0100 — a full restart, so finishing creation lands back on the
# splash and the player presses P. Enhanced mode drops that CP/M dead end and
# enters the world directly. Needs a content dir, because the overworld cannot
# load a sector without mapxNN.
if [ -n "$CONTENT" ]; then
    T5KEYS="$WORK/t5.keys"
    printf 'ESC\nC\n1\n5\n1\n5\n1\n5\n1\n5\n1\n5\n1\n5\nM\n1\n1\nB\nR\nI\nT\nI\nS\nH\n0x0d\n0x0d\n0x0d\n0x0d\n' > "$T5KEYS"

    rm -rf "$WORK/t5orig"; mkdir -p "$WORK/t5orig"
    ./u2 --headless --data-dir "$CONTENT" --save-dir "$WORK/t5orig" \
         --script "$T5KEYS" --dump-each > "$WORK/t5orig.out" 2>&1
    grep -q "CMD:" "$WORK/t5orig.out" \
        && bad "original mode entered the world after creation; it must restart to the title" \
        || ok "original mode: completed creation restarts to the title, not the world"

    rm -rf "$WORK/t5enh"; mkdir -p "$WORK/t5enh"
    ./u2 --headless --enhanced --data-dir "$CONTENT" --save-dir "$WORK/t5enh" \
         --script "$T5KEYS" --dump-each > "$WORK/t5enh.out" 2>&1
    grep -q "CMD:" "$WORK/t5enh.out" \
        && ok "enhanced mode: completed creation drops straight into the world" \
        || bad "enhanced mode did not enter the world after creation"

    # An abandoned creation must not run the tail at all.
    rm -rf "$WORK/t5ab"; mkdir -p "$WORK/t5ab"
    printf 'ESC\nC\n' > "$WORK/t5ab.keys"
    ./u2 --headless --data-dir "$CONTENT" --save-dir "$WORK/t5ab" \
         --script "$WORK/t5ab.keys" --dump-each > "$WORK/t5ab.out" 2>&1
    grep -q "CMD:" "$WORK/t5ab.out" \
        && bad "abandoning creation still ran the restart tail" \
        || ok "abandoned creation (ESC) does not run the tail"
else
    printf '  SKIP  T5 creation-tail checks (no content dir holding mapx00)\n'
fi

printf '\n'
if [ "$fail" -eq 0 ]; then
    printf 'CP4 TEST: PASS\n'
else
    printf 'CP4 TEST: FAIL\n'
fi
exit "$fail"
