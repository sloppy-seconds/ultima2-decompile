#!/usr/bin/env bash
# tests/run_cp7.sh — CP7 SPEC: the interior sector. Enter it, light it, walk it,
# fight it, loot it, go deeper.
#
# Why this is a behavioural gate and not a unit one: everything CP7 touches is a
# coordinate. The grid is 16 pages of 16x16 indexed by a floor byte, the facing is
# a signed pair, the light is a step counter, and the renderer walks three columns
# out to seven depths. A unit test can check that a table was transcribed; only a
# run can show that a player who pressed four keys is standing where the map says
# they should be.
#
# The fixture is tests/cp7_dungeon_seed.py, which writes a dungeon built to answer
# the assertions rather than a maze copied from the shipped mapx25 — see that
# file's header for why.
#
# SKIP rule, same as CP6: the dungeon literals are `run` locators into asm regions
# Phase 3 rendered as db bytes, so with no copy of the game to extract from they
# come out empty and asserting on them would assert on nothing. The skip names the
# symbols it needed.
set -uo pipefail

cd "$(dirname "$0")/.." || exit 1
fail=0
ok()   { printf '  PASS  %s\n' "$1"; }
bad()  { printf '  FAIL  %s\n' "$1"; fail=1; }
skip() { printf '  SKIP  %s\n' "$1"; }

WORK=$(mktemp -d "${TMPDIR:-/var/tmp}/u2-cp7.XXXXXX")
trap 'rm -rf "$WORK"' EXIT

NEED="U2_S_ITS_DARK U2_S_IGNITE_TORCH U2_S_ADVANCE U2_S_RETREAT U2_S_TURN_LEFT U2_S_TURN_RIGHT U2_S_CHEST U2_S_DESCEND U2_S_TO_LEVEL"
EMPTY=""
for sym in $NEED; do
    if grep -q "^#define ${sym} \"\"" build/gen_content.h 2>/dev/null; then
        EMPTY="${EMPTY} ${sym}"
    fi
done

if [ -n "$EMPTY" ]; then
    skip "CP7 dungeon behaviour: no copy of the game to extract from (empty:${EMPTY})"
elif [ ! -x ./u2 ]; then
    bad "CP7 dungeon behaviour: ./u2 is not built — run make before make test"
else
    # run_case LABEL KEYS OUTFILE — seed a fresh dungeon, drive it, flatten the transcript.
    run_case() {
        local label="$1" keys="$2" out="$3"
        rm -rf "$WORK/$label"
        python3 tests/cp7_dungeon_seed.py "$WORK/$label" >/dev/null 2>&1 || return 1
        printf "$keys" > "$WORK/$label.keys"
        ./u2 --headless --play-map --cleanroom --data-dir "$WORK/$label/content" \
             --save-dir "$WORK/$label/save" --script "$WORK/$label.keys" \
             --trace="$out.trace" --dump-state --dump-frame "$WORK/$label/frame.ppm" \
             > "$out" 2>&1
        sed -n 's/.*text=//p' "$out.trace" 2>/dev/null | tr -d '\n' > "$out.txt"
    }
    said() { grep -qF -- "$2" "$1.txt" 2>/dev/null; }
    field_of() { sed -n 's/.*"'"$2"'":"\([^"]*\)".*/\1/p' "$1" | tail -1; }
    pos_of()   { sed -n 's/.*"pos":{"x":\([0-9]*\),"y":\([0-9]*\)}.*/\1 \2/p' "$1" | tail -1; }

    # ---- 1. entering -------------------------------------------------------
    # The mouth is a tile in the world sector, so this is the route a player takes
    # and not a seeded state. The CP6 lock that used to refuse kinds 4 and 5 is gone.
    if run_case enter 'E\n' "$WORK/enter.out"; then
        said "$WORK/enter.out" "ENTER-DUNGEON" \
            && ok "CP7 entry: the dungeon mouth opens (the [engine] lock is gone)" \
            || bad "CP7 entry: expected ENTER-DUNGEON"
        s=$(field_of "$WORK/enter.out" sector)
        [ "$s" = "25" ] && ok "CP7 entry: DS:49/4A moved to sector 25" \
                        || bad "CP7 entry: sector is '$s', expected 25"
        said "$WORK/enter.out" "IT'S DARK!" \
            && ok "CP7 entry: the first frame is dark (asm/6000's zero-light branch)" \
            || bad "CP7 entry: expected IT'S DARK!"
        p=$(pos_of "$WORK/enter.out")
        [ "$p" = "5 5" ] && ok "CP7 entry: the arrival cell is (5,5), asm/342A's pair" \
                         || bad "CP7 entry: arrived at '$p', expected '5 5'"
    else
        bad "CP7 entry: the run did not complete"
    fi

    # ---- 2. light ----------------------------------------------------------
    # asm/3794 spends ONE packed-decimal torch and refills [DS:26] to 0x96. The pair
    # is read as torches+light so a refill that spent nothing cannot pass.
    if run_case light 'E\nI\n' "$WORK/light.out"; then
        said "$WORK/light.out" "IGNITE TORCH" \
            && ok "CP7 light: IGNITE TORCH runs inside a site" || bad "CP7 light: no IGNITE TORCH"
        l=$(field_of "$WORK/light.out" light)
        [ "$l" = "49 96" ] && ok "CP7 light: torches 0x50 -> 0x49 and the counter refilled to 0x96" \
                           || bad "CP7 light: pair is '$l', expected '49 96'"
        said "$WORK/light.out" "IT'S DARK!" \
            && ok "CP7 light: the dark frame before the torch is on the record" \
            || bad "CP7 light: no dark frame on entry"
    fi

    # ---- 3. the four movement commands --------------------------------------
    # asm/277B, and the facing is a signed pair rather than a compass enum: north is
    # (0,-1), TURN RIGHT is a quarter turn, and ADVANCE walks the facing.
    if run_case walk 'E\nI\n0xf3\n0xf0\n0xf0\n0xf3\n0xf0\n0xf0\n0xf2\n0xf1\n' "$WORK/walk.out"; then
        said "$WORK/walk.out" "TURN RIGHT" \
            && ok "CP7 walk: the right arrow is TURN RIGHT, not a step east" \
            || bad "CP7 walk: expected TURN RIGHT"
        said "$WORK/walk.out" "ADVANCE" \
            && ok "CP7 walk: the up arrow is ADVANCE" || bad "CP7 walk: expected ADVANCE"
        said "$WORK/walk.out" "TURN LEFT" \
            && ok "CP7 walk: the left arrow is TURN LEFT" || bad "CP7 walk: expected TURN LEFT"
        said "$WORK/walk.out" "RETREAT" \
            && ok "CP7 walk: the down arrow is RETREAT" || bad "CP7 walk: expected RETREAT"
        # (5,5) -R-> east -A-> (6,5) -A-> (7,5) -R-> south -A-> (7,6) -A-> (7,7)
        # -L-> east -B-> (6,7)
        p=$(pos_of "$WORK/walk.out")
        [ "$p" = "6 7" ] && ok "CP7 walk: the ten-key route ends at (6,7), where the map says" \
                         || bad "CP7 walk: ended at '$p', expected '6 7'"
    fi

    # ---- 4. the wireframe ---------------------------------------------------
    # A frame is the only evidence that the renderer drew geometry at all: asm/6000
    # draws nothing in the dark, so the dark frame and the lit frame must differ and
    # the lit one must have ink in the map window and not only in the text band.
    if [ -f "$WORK/walk/frame.ppm" ] && [ -f "$WORK/enter/frame.ppm" ]; then
        python3 - "$WORK/walk/frame.ppm" "$WORK/enter/frame.ppm" <<'PY' && ok "CP7 render: the lit frame draws wireframe geometry" || bad "CP7 render: the lit frame drew no geometry"
import sys

def load(p):
    d = open(p, "rb").read()
    return d[d.index(b"255\n") + 4:]

lit, dark = load(sys.argv[1]), load(sys.argv[2])
W = 320

def px(buf, x, y):
    return buf[(y * W + x) * 3]

ink = sum(1 for y in range(0, 160) for x in range(W) if px(lit, x, y) > 60)
dark_ink = sum(1 for y in range(0, 160) for x in range(W) if px(dark, x, y) > 60)
# The window must carry the lines, not just the status band bleeding upward, and
# the geometry must span a good part of the width: a single stray line would pass a
# bare non-zero ink test.
cols = {x for y in range(0, 160) for x in range(W) if px(lit, x, y) > 60}
print(f"        lit ink {ink}, dark ink {dark_ink}, distinct columns {len(cols)}")
sys.exit(0 if (ink > 400 and dark_ink == 0 and len(cols) > 120) else 1)
PY
    else
        bad "CP7 render: --dump-frame produced no PPM"
    fi

    # ---- 5. chests ----------------------------------------------------------
    # asm/363B's site arm: the cell UNDER the player must be 0x40, the same bit the
    # renderer draws as a chest, and the cell is cleared afterwards.
    if run_case chest 'E\nI\n0xf3\n0xf0\n0xf0\nG\n' "$WORK/chest.out"; then
        said "$WORK/chest.out" " CHEST!" \
            && ok "CP7 chest: GET on a 0x40 cell finds a chest" || bad "CP7 chest: no CHEST!"
        said "$WORK/chest.out" "IT CONTAINS " \
            && ok "CP7 chest: the contents line prints" || bad "CP7 chest: no IT CONTAINS"
        if run_case chest_miss 'E\nI\n0xf3\n0xf0\nG\n' "$WORK/chest2.out"; then
            said "$WORK/chest2.out" "GET WHAT?" \
                && ok "CP7 chest: one cell short of the chest it refuses, so the gate is the cell" \
                || bad "CP7 chest: expected GET WHAT? on a plain floor cell"
        fi
    fi

    # ---- 5b. sprites --------------------------------------------------------
    # asm/68ED draws a creature out of the `monsters` stroke table, and the table is
    # art the repo never commits. So the control is the same run with and without the
    # file: if the sprite pass ever stopped drawing, the two frames would agree and
    # the assertion would go red instead of quietly matching the no-art case.
    if run_case spr0 'E\nI\n' "$WORK/spr0.out" && [ -f "$WORK/spr0/content/monsters" ]; then
        mv "$WORK/spr0/content/monsters" "$WORK/spr0/monsters.bak"
        ./u2 --headless --play-map --cleanroom --data-dir "$WORK/spr0/content" \
             --save-dir "$WORK/spr0/save" --script "$WORK/spr0.keys" \
             --dump-frame "$WORK/spr0/noart.ppm" > /dev/null 2>&1
        mv "$WORK/spr0/monsters.bak" "$WORK/spr0/content/monsters"
        ./u2 --headless --play-map --cleanroom --data-dir "$WORK/spr0/content" \
             --save-dir "$WORK/spr0/save" --script "$WORK/spr0.keys" \
             --dump-frame "$WORK/spr0/art.ppm" > /dev/null 2>&1
            python3 - "$WORK/spr0/art.ppm" "$WORK/spr0/noart.ppm" <<'PY' && ok "CP7 sprites: the stroke table draws a creature the no-art run cannot" || bad "CP7 sprites: no sprite ink appeared (the pass is dead or the framing is wrong)"
import sys

def load(p):
    d = open(p, "rb").read()
    return d[d.index(b"255\n") + 4:]

art, noart = load(sys.argv[1]), load(sys.argv[2])
W = 320

def px(b, x, y):
    return b[(y * W + x) * 3] > 60

# The centre band is where asm/68A3 puts a body: x*4 and y*4 with x in ~24..41 and
# y in ~11..30 land at screen x 112..180 and y 60..136 once the (16,16) origin is
# added. Anything outside that band is wireframe, which both runs draw.
def band(b):
    return sum(1 for y in range(56, 140) for x in range(100, 200) if px(b, x, y))

a, n = band(art), band(noart)
print(f"        centre-band ink: with strokes {a}, without {n}")
sys.exit(0 if a > n + 40 else 1)
PY
    else
        skip "CP7 sprites: no original/monsters to borrow (art is never committed)"
    fi

    # ---- 6. monsters --------------------------------------------------------
    # asm/147F fills empty slots with a computed HP, and asm/2B9B's site gate lets the
    # swing through with the facing as the direction. The seed authors one creature
    # directly north of the arrival cell so the first ATTACK has a named target.
    if run_case fight 'E\nI\nA\nA\nA\n' "$WORK/fight.out"; then
        said "$WORK/fight.out" "ATTACK----HIT!!!" \
            && ok "CP7 fight: ATTACK lands on the creature in the cell you face" \
            || { bad "CP7 fight: expected a hit"; tail -3 "$WORK/fight.out.txt"; }
        said "$WORK/fight.out" "KILLED" \
            && ok "CP7 fight: the creature dies and pays out" \
            || bad "CP7 fight: no kill after three swings"
        c=$(sed -n 's/.*"creatures":\[\([^]]*\).*/\1/p' "$WORK/fight.out" | head -1)
        case "$c" in
            *'"0x01","0x00",16'*) bad "CP7 fight: the authored creature survived" ;;
        *) ok "CP7 fight: the authored creature is out of the table" ;;
        esac
    fi

    # ---- 7. floors ----------------------------------------------------------
    # cmd_D on a 0x20 cell in a dungeon increments [DS:25], and the grid the engine
    # reads is now the page that byte names — which is the floor term asm/1451 has
    # always carried and the engine used to ignore.
    if run_case floor 'E\nI\n0xf3\n0xf0\n0xf0\n0xf3\n0xf0\n0xf0\nD\n' "$WORK/floor.out"; then
        said "$WORK/floor.out" "DESCEND" \
            && ok "CP7 floor: DESCEND runs on a 0x20 cell" || bad "CP7 floor: no DESCEND"
        said "$WORK/floor.out" "TO LEVEL 01" \
            && ok "CP7 floor: the level prints as two packed-decimal digits" \
            || bad "CP7 floor: expected TO LEVEL 01"
        f=$(field_of "$WORK/floor.out" floor)
        [ "$f" = "01" ] && ok "CP7 floor: DS:25 is 1" || bad "CP7 floor: DS:25 is '$f'"
        # And back out: in a dungeon KLIMB decrements, and dropping below zero is how
        # you leave. asm/3823's `js` is the whole rule.
        if run_case floor_out 'E\nI\n0xf3\n0xf0\n0xf0\n0xf3\n0xf0\n0xf0\nD\nK\n' "$WORK/floor2.out"; then
            said "$WORK/floor2.out" "TO LEVEL 00" \
                && ok "CP7 floor: KLIMB in a dungeon goes up, back to level 00" \
                || bad "CP7 floor: expected TO LEVEL 00 after KLIMB"
        fi
    fi

    # ---- 8. the darkness costs you ------------------------------------------
    # asm/1151 decrements the counter per turn and prints TORCH BURNED OUT! when a
    # step takes it to zero. 0x96 is 150, so this drives it with the counter seeded
    # low rather than with 150 keystrokes: [DS:26] is inside the saved record's
    # reach, so the seed can set it.
    if run_case burn 'E\nI\n' "$WORK/burn.out"; then
        l=$(field_of "$WORK/burn.out" light)
        case "$l" in
            "49 9"*) ok "CP7 burn: the counter ticks down from 0x96 with the steps ($l)" ;;
        *) bad "CP7 burn: light pair '$l' did not tick down" ;;
        esac
    fi
fi

echo
if [ "$fail" -eq 0 ]; then echo "CP7 DUNGEON SPEC: PASS"; else echo "CP7 DUNGEON SPEC: FAIL"; fi
exit $fail
