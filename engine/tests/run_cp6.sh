#!/usr/bin/env bash
# tests/run_cp6.sh — CP6 commerce SPEC: the TRANSACT ray, the vendor selector, the price.
#
# Three things happen here, in the order run_cp5.sh established:
#
#   1. tests/commerce_check.c is compiled and run. It is the pure half: the price walk,
#      the selector table, and the BCD charge. It needs no content and runs in CI.
#   2. The behavioural half drives ./u2 against a synthetic sector built by
#      tests/cp6_commerce_seed.py — engine-authored filler, never the player's own files —
#      and asserts the shop text, the gold, and the owned-count slot for each purchase.
#   3. The gaps are asserted too. The pub, the cleric shrine, the wizard shoppe, the clue
#      seller and the talking branch are NOT implemented, and a gate that only checks what
#      works cannot tell an unimplemented branch from a broken one. So the pub case asserts
#      silence, and the two broken-ray cases assert the refusal.
#
# The behavioural half SKIPs when the content strings are empty, which is what they are
# without a copy of the game to extract from (docs/phase4-plan.md: the engine ships zero
# content). A skip that can hide a failure is not a skip — so the skip names the symbols it
# needed, and commerce_check still runs.
set -uo pipefail

cd "$(dirname "$0")/.." || exit 1
fail=0
ok()   { printf '  PASS  %s\n' "$1"; }
bad()  { printf '  FAIL  %s\n' "$1"; fail=1; }
skip() { printf '  SKIP  %s\n' "$1"; }

WORK=$(mktemp -d "${TMPDIR:-/var/tmp}/u2-cp6.XXXXXX")
trap 'rm -rf "$WORK"' EXIT

# --- 1. the pure spec --------------------------------------------------------
if cc -std=c11 -Wall -Wextra -Werror -Isrc -Ibuild -o "$WORK/commerce_check" \
        tests/commerce_check.c src/core/*.c src/game/*.c src/debug/*.c 2>"$WORK/cc.err"; then
    "$WORK/commerce_check" > "$WORK/cc.out" 2>&1
    rc=$?
    sed 's/^/        /' "$WORK/cc.out"
    n=$(sed -n 's/^commerce_check: \([0-9]\{1,\}\) checks, [0-9]\{1,\} failures$/\1/p' "$WORK/cc.out" | tail -1)
    if [ "$rc" -eq 0 ] && [ -n "$n" ]; then
        ok "CP6 commerce spec: ${n:-0} checks, price walk + selector + charge"
    else
        bad "CP6 commerce spec: commerce_check reported failures (rc=$rc)"
    fi
else
    bad "CP6 commerce spec: commerce_check.c did not compile"
    sed 's/^/        /' "$WORK/cc.err" | head -10
fi

# --- 2/3. the behavioural half ----------------------------------------------
# Every shop literal here is a `run` locator (the menus are multi-segment db lines the asm
# fallback cannot index), so with no copy of the game they come out empty and the prints are
# empty too. Asserting on them then would be asserting on nothing.
NEED="U2_S_ARMOUR_MENU U2_S_WEAPONS_MENU U2_S_TRANSPORT_MENU U2_S_FOOD_COSTS U2_S_SHOP_SOLD"
EMPTY=""
for sym in $NEED; do
    if grep -q "^#define ${sym} \"\"" build/gen_content.h 2>/dev/null; then
        EMPTY="${EMPTY} ${sym}"
    fi
done

if [ -n "$EMPTY" ]; then
    skip "CP6 commerce behaviour: no copy of the game to extract from (empty:${EMPTY})"
elif [ ! -x ./u2 ]; then
    bad "CP6 commerce behaviour: ./u2 is not built — run make before make test"
else
    run_case() {   # run_case SEEDCASE LABEL KEYS OUTFILE
        local seed="$1" label="$2" keys="$3" out="$4"
        rm -rf "$WORK/$label"
        python3 tests/cp6_commerce_seed.py "$WORK/$label" "$seed" >/dev/null 2>&1 || return 1
        printf "$keys" > "$WORK/$label.keys"
        ./u2 --headless --play-map --cleanroom --data-dir "$WORK/$label/content" \
             --save-dir "$WORK/$label/save" --script "$WORK/$label.keys" \
             --dump-each --dump-state > "$out" 2>&1
    }
    gold_of() { sed -n 's/.*"gold":\([0-9]\{1,\}\).*/\1/p' "$1" | tail -1; }
    field_of() { sed -n 's/.*"'"$2"'":"\([^"]*\)".*/\1/p' "$1" | tail -1; }

    # (a) armour, the known-good end-to-end case: sector 32 (38,5), T + north, item 1, Y.
    #     Quote 0012 and gold 9999 -> 9987 are both live observations of the ORIGINAL
    #     (captures/spice86/armour-buy), so this is the engine matching the game and not
    #     matching itself.
    if run_case armour armour 'T\n0xf0\n1\nY\n' "$WORK/armour.out"; then
        grep -q "AH! YES! CLOTH" "$WORK/armour.out" \
            && ok "CP6 T: the ray reaches the armour shoppe and echoes the pool name" \
            || { bad "CP6 T: no armour name from (38,5) north"; sed -n '21,24p' "$WORK/armour.out"; }
        grep -q "YOU ONLY 0012" "$WORK/armour.out" \
            && ok "CP6 T: CLOTH quotes 0012, the number the original quoted live" \
            || bad "CP6 T: expected 'FOR YOU ONLY 0012'"
        [ "$(gold_of "$WORK/armour.out")" = "9987" ] \
            && ok "CP6 T: gold 9999 -> 9987, the observed charge" \
            || bad "CP6 T: gold is $(gold_of "$WORK/armour.out"), expected 9987"
        grep -q "SOLD!" "$WORK/armour.out" \
            && ok "CP6 T: the yes branch prints SOLD!" \
            || bad "CP6 T: no SOLD! on a yes answer"
    else
        bad "CP6 T: armour case did not seed"
    fi

    # (b) declining costs nothing: asm/2017's non-'Y' arm prints OH, WELL. and never calls
    #     the charge routine at all.
    if run_case armour armour-decline 'T\n0xf0\n1\nN\n' "$WORK/decline.out"; then
        [ "$(gold_of "$WORK/decline.out")" = "9999" ] \
            && ok "CP6 T: answering N leaves gold at 9999 (asm/202B is past the branch)" \
            || bad "CP6 T: a declined purchase took gold: $(gold_of "$WORK/decline.out")"
        grep -q "OH, WELL." "$WORK/decline.out" \
            && ok "CP6 T: the refusal line is the original's OH, WELL." \
            || bad "CP6 T: expected 'OH, WELL.' on a no answer"
    fi

    # (c) weapons: same shape, price index = the digit itself, so item 1 is 0008 and item 3
    #     is 0020 — the axe number the live stop at asm/20AB produced.
    if run_case weapons weapons 'T\n0xf0\n3\nY\n' "$WORK/weapons.out"; then
        grep -q "YES! A AXE" "$WORK/weapons.out" \
            && ok "CP6 T: the north-west half of a town is the weapons shoppe" \
            || bad "CP6 T: no weapons name from (9,5) north"
        grep -q "YOU ONLY 0020" "$WORK/weapons.out" \
            && ok "CP6 T: AX quotes 0020, the number asm/20AB was stopped leaving" \
            || bad "CP6 T: expected 'FOR YOU ONLY 0020' for menu item 3"
        [ "$(gold_of "$WORK/weapons.out")" = "9979" ] \
            && ok "CP6 T: the axe charge is 20, as the live purchase took it" \
            || bad "CP6 T: axe gold is $(gold_of "$WORK/weapons.out"), expected 9979"
    fi

    # (d) transport: no menu digit at all — the horse price is the constant 4 — and the
    #     purchase mounts, which is the only place outside cmd_B the travel mode changes.
    if run_case transport transport 'T\n0xf0\nY\n' "$WORK/transport.out"; then
        grep -q "GOLD, DEAL, OK" "$WORK/transport.out" \
            && ok "CP6 T: the south-east half of a town is the transport shoppe" \
            || bad "CP6 T: no transport offer from (38,40) north"
        grep -q "0032" "$WORK/transport.out" \
            && ok "CP6 T: a horse quotes 0032 at maxed stats" \
            || bad "CP6 T: expected the horse price 0032"
        [ "$(gold_of "$WORK/transport.out")" = "9967" ] \
            && ok "CP6 T: the horse charge is 32, the first live price asm/20AB reproduced" \
            || bad "CP6 T: horse gold is $(gold_of "$WORK/transport.out"), expected 9967"
        [ "$(field_of "$WORK/transport.out" stamp)" = "22" ] \
            && ok "CP6 T: buying the horse sets DS:13 to 0x22, no tile and no inventory slot" \
            || bad "CP6 T: DS:13 is $(field_of "$WORK/transport.out" stamp), expected 22"
    fi

    # (e) grocery: a village's north-east half, the constant index 3, and the food byte
    #     moving by ONE in packed decimal (asm/181A), which is not what "PER 100" suggests.
    if run_case grocery grocery 'T\n0xf0\nY\n' "$WORK/grocery.out"; then
        grep -q "COSTS 0020" "$WORK/grocery.out" \
            && ok "CP6 T: the grocery quote is 0020, not the 0200 this project repeated for a week" \
            || { bad "CP6 T: expected 'THE FOOD HERE COSTS 0020'"; sed -n '21,24p' "$WORK/grocery.out"; }
        [ "$(gold_of "$WORK/grocery.out")" = "9979" ] \
            && ok "CP6 T: the grocery charge is 20, measured at asm/2052 and in gold" \
            || bad "CP6 T: grocery gold is $(gold_of "$WORK/grocery.out"), expected 9979"
        [ "$(field_of "$WORK/grocery.out" food)" = "51 00 00" ] \
            && ok "CP6 T: food 5000 -> 5100: asm/181A adds one unit to DS:53, not a hundred" \
            || bad "CP6 T: food is $(field_of "$WORK/grocery.out" food), expected '51 00 00'"
    fi

    # (f) the pub is dispatched and unimplemented. Silence is the honest answer, and it is
    #     asserted so that a future half-implementation cannot land quietly.
    if run_case pub pub 'T\n0xf0\n' "$WORK/pub.out"; then
        if grep -qE "WELCOME TO THE PUB|1-BUY" "$WORK/pub.out"; then
            bad "CP6 T: the pub printed a menu, and commerce.c says it is not implemented"
        else
            ok "CP6 T: the pub quadrant stays silent, matching the documented gap"
        fi
    fi

    # (g) the two ways the ray fails. Both must print FUNNY, NO RESPONSE! and nothing else,
    #     and neither may open a shop.
    for c in nosign nomarker; do
        if run_case "$c" "$c" 'T\n0xf0\n' "$WORK/$c.out"; then
            grep -q "FUNNY, NO R" "$WORK/$c.out" \
                && ok "CP6 T: ${c} ray refuses with FUNNY, NO RESPONSE!" \
                || { bad "CP6 T: ${c} should refuse; got:"; sed -n '21,24p' "$WORK/$c.out"; }
            grep -q "SHOPPE\|COSTS" "$WORK/$c.out" \
                && bad "CP6 T: ${c} refused and opened a shop anyway" \
                || ok "CP6 T: ${c} opens nothing"
        fi
    done
fi

printf '\n'
if [ "$fail" -eq 0 ]; then
    printf 'CP6 SPEC: PASS\n'
else
    printf 'CP6 SPEC: FAIL\n'
fi
exit "$fail"
