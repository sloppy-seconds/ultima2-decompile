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
             --trace="$out.trace" --dump-each --dump-state > "$out" 2>&1
        # Flatten the transcript: the engine prints a menu in several str_out calls (the literal,
        # then the pool name, then the price), so a phrase like "AH! YES! CLOTH" spans three of
        # them. Joining every text= field into one stream is what makes a whole-phrase grep work.
        sed -n 's/.*text=//p' "$out.trace" 2>/dev/null | tr -d '\n' > "$out.txt"
    }
    # Text assertions read the transcript, not the final frame: the message band is four rows and
    # scrolls, so a long exchange loses its opening lines off the top of the screen and a frame
    # grep silently under-checks. said OUTFILE "phrase".
    said() { grep -qF -- "$2" "$1.txt" 2>/dev/null; }
    gold_of() { sed -n 's/.*"gold":\([0-9]\{1,\}\).*/\1/p' "$1" | tail -1; }
    field_of() { sed -n 's/.*"'"$2"'":"\([^"]*\)".*/\1/p' "$1" | tail -1; }

    # (a) armour, the known-good end-to-end case: sector 32 (38,5), T + north, item 1, Y.
    #     Quote 0012 and gold 9999 -> 9987 are both live observations of the ORIGINAL
    #     (captures/spice86/armour-buy), so this is the engine matching the game and not
    #     matching itself.
    if run_case armour armour 'T\n0xf0\n1\nY\n' "$WORK/armour.out"; then
        said "$WORK/armour.out" "AH! YES! CLOTH" \
            && ok "CP6 T: the ray reaches the armour shoppe and echoes the pool name" \
            || { bad "CP6 T: no armour name from (38,5) north"; sed -n '21,24p' "$WORK/armour.out"; }
        said "$WORK/armour.out" "YOU ONLY 0012" \
            && ok "CP6 T: CLOTH quotes 0012, the number the original quoted live" \
            || bad "CP6 T: expected 'FOR YOU ONLY 0012'"
        [ "$(gold_of "$WORK/armour.out")" = "9987" ] \
            && ok "CP6 T: gold 9999 -> 9987, the observed charge" \
            || bad "CP6 T: gold is $(gold_of "$WORK/armour.out"), expected 9987"
        said "$WORK/armour.out" "SOLD!" \
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
        said "$WORK/decline.out" "OH, WELL." \
            && ok "CP6 T: the refusal line is the original's OH, WELL." \
            || bad "CP6 T: expected 'OH, WELL.' on a no answer"
    fi

    # (c) weapons: same shape, price index = the digit itself, so item 1 is 0008 and item 3
    #     is 0020 — the axe number the live stop at asm/20AB produced. The offer line is
    #     "AH! YES! AXE" in the original's own frame (captures/spice86/g23-weapons/w5-axe.png),
    #     so the shoppe does name the item it is offering; what it does not do is enumerate the
    #     pool the way cmd_W's menu does, and that is the gap asserted next.
    if run_case weapons weapons 'T\n0xf0\n3\nY\n' "$WORK/weapons.out"; then
        said "$WORK/weapons.out" "AH! YES! AXE" \
            && ok "CP6 T: the north-west half of a town is the weapons shoppe" \
            || bad "CP6 T: no weapons name from (9,5) north"
        for other in MACE PHASER "QUICK SWORD"; do
            said "$WORK/weapons.out" "$other" \
                && bad "CP6 T: the weapons shoppe enumerated the pool (found $other)" \
                || true
        done
        ok "CP6 T: the weapons shoppe offers one item and does not list the pool"
        said "$WORK/weapons.out" "YOU ONLY 0020" \
            && ok "CP6 T: AX quotes 0020, the number asm/20AB was stopped leaving" \
            || bad "CP6 T: expected 'FOR YOU ONLY 0020' for menu item 3"
        [ "$(gold_of "$WORK/weapons.out")" = "9979" ] \
            && ok "CP6 T: the axe charge is 20, as the live purchase took it" \
            || bad "CP6 T: axe gold is $(gold_of "$WORK/weapons.out"), expected 9979"
    fi

    # (d) transport: no menu digit at all — the horse price is the constant 4 — and the
    #     purchase mounts, which is the only place outside cmd_B the travel mode changes.
    if run_case transport transport 'T\n0xf0\nY\n' "$WORK/transport.out"; then
        said "$WORK/transport.out" "GOLD, DEAL, OK" \
            && ok "CP6 T: the south-east half of a town is the transport shoppe" \
            || bad "CP6 T: no transport offer from (38,40) north"
        said "$WORK/transport.out" "0032" \
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
        said "$WORK/grocery.out" "COSTS 0020" \
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
        if said "$WORK/pub.out" "WELCOME TO THE PUB" || said "$WORK/pub.out" "1-BUY"; then
            bad "CP6 T: the pub printed a menu, and commerce.c says it is not implemented"
        else
            ok "CP6 T: the pub quadrant stays silent, matching the documented gap"
        fi
    fi

    # (g) the two ways the ray fails. Both must print FUNNY, NO RESPONSE! and nothing else,
    #     and neither may open a shop.
    for c in nosign nomarker; do
        if run_case "$c" "$c" 'T\n0xf0\n' "$WORK/$c.out"; then
            said "$WORK/$c.out" "FUNNY, NO R" \
                && ok "CP6 T: ${c} ray refuses with FUNNY, NO RESPONSE!" \
                || { bad "CP6 T: ${c} should refuse; got:"; sed -n '21,24p' "$WORK/$c.out"; }
            if said "$WORK/$c.out" "SHOPPE" || said "$WORK/$c.out" "COSTS"; then
                bad "CP6 T: ${c} refused and opened a shop anyway"
            else
                ok "CP6 T: ${c} opens nothing"
            fi
        fi
    done
    # --- the two command letters first observed on 2026-10-29 -----------------
    # cmd_R (READY WEAPON) and cmd_N (NEGATE TIME). Both are gated here because both were
    # read-only-until-this-week, and cmd_N is the letter that had never executed in any harvest.

    # (h) ready a weapon you own and are agile enough for. The seed owns 1..9 except 7, and
    #     agility is 0x40 = 64 packed, so digit 8 passes and digit 9 (72) does not.
    if run_case armour cmdr-ok 'R\n3\n' "$WORK/cmdr-ok.out"; then
        said "$WORK/cmdr-ok.out" "AXE READY." \
            && ok "CP6 R: READY WEAPON echoes the pool NAME and readies the digit" \
            || { bad "CP6 R: expected 'AXE READY.'"; sed -n '21,24p' "$WORK/cmdr-ok.out"; }
    fi
    if run_case armour cmdr-owned 'R\n7\n' "$WORK/cmdr-owned.out"; then
        said "$WORK/cmdr-owned.out" "NOT OWNED" \
            && ok "CP6 R: an unowned weapon is refused on [DS:76 + digit]" \
            || bad "CP6 R: expected NOT OWNED for the weapon the seed does not hold"
        said "$WORK/cmdr-owned.out" " READY." \
            && bad "CP6 R: readied a weapon the seed does not own" \
            || ok "CP6 R: the refusal path leaves nothing readied"
    fi
    if run_case armour cmdr-agile 'R\n9\n' "$WORK/cmdr-agile.out"; then
        said "$WORK/cmdr-agile.out" "AGILE ENOUGH TO WIELD!" \
            && ok "CP6 R: digit 9 fails the AGILITY gate (9*8=72 > packed 0x40=64)" \
            || bad "CP6 R: expected the agility refusal at digit 9"
        said "$WORK/cmdr-agile.out" "STRONG ENOUGH" \
            && bad "CP6 R: used cmd_W's strength gate instead of agility" \
            || ok "CP6 R: the gate is agility, not the armour handler's strength"
    fi

    # (i) NEGATE TIME spends a STRANGE COIN (items_held[13], which is what DS:E3 is) and sets the
    #     creature-move freeze counter, which then ticks like the paralysis bytes.
    if run_case armour cmdn 'N\n' "$WORK/cmdn.out"; then
        said "$WORK/cmdn.out" "YOU RUB A COIN" \
            && ok "CP6 N: with a strange coin, NEGATE TIME falls into the coin rub" \
            || { bad "CP6 N: expected 'YOU RUB A COIN...'"; sed -n '21,24p' "$WORK/cmdn.out"; }
        items=$(sed -n 's/.*"items":"\([^"]*\)".*/\1/p' "$WORK/cmdn.out" | tail -1)
        case "$items" in
            *"00 00 00 00 00 00 00 00 00 00 00 00 00 00"*)
                ok "CP6 N: the strange coin was spent (items_held[13] -> 0)" ;;
        *)  bad "CP6 N: items did not lose the coin: $items" ;;
        esac
        para=$(sed -n 's/.*"paralysis":"\([^"]*\)".*/\1/p' "$WORK/cmdn.out" | tail -1)
        case "$para" in
            "14 "*) ok "CP6 N: DS:26A set to 0x14, the creature-move freeze" ;;
        *)  bad "CP6 N: DS:26A is '$para', expected 14 ..." ;;
        esac
    fi
    if run_case armour cmdn2 'N\nN\n' "$WORK/cmdn2.out"; then
        said "$WORK/cmdn2.out" "EINSTEIN" \
            && ok "CP6 N: with no coin left it refuses and changes nothing" \
            || { bad "CP6 N: expected the second N to refuse"; sed -n '21,24p' "$WORK/cmdn2.out"; }
    fi
fi

printf '\n'
if [ "$fail" -eq 0 ]; then
    printf 'CP6 SPEC: PASS\n'
else
    printf 'CP6 SPEC: FAIL\n'
fi
exit "$fail"
