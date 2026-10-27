#!/usr/bin/env bash
# tests/run_cp5.sh — CP5 combat acceptance SPEC (tickets C1, C2, C6).
#
# src/game/combat.c exists and implements C1/C2/C6, so the behavioural run is the
# main event. The SKIP path is kept for the case where combat.c is removed again
# (a revert, a branch bisect) so the spec can still land ahead of the code. This
# runner does three things:
#
#   1. Always syntax-check tests/combat_check.c, so the specification is proven
#      to be well-formed C and its API contract is pinned. This runs in CI.
#   2. Always run the two fixture controls, so the spec is proven to discriminate
#      whether or not combat.c is present.
#   3. Run the behavioural spec against src/game/combat.c. If that file is
#      absent, each ticket is reported SKIP with the exact missing hook named and
#      the suite stays green (a skipped spec must not turn the gate red).
#
# The spec (combat_check.c) is written to DISCRIMINATE: a boolean-immunity
# resist, a wrong roll threshold, a fixed (non-random) counter, or a theft that
# flags rather than deletes each fail at least one assertion. See the file's
# header for the byte citations behind every expectation.
#
# That discrimination is PROVEN, not asserted. Two fixture models ship with the
# spec: tests/combat_model_faithful.c (must pass) and
# tests/combat_model_boolean_wrong.c (must fail). They run on every `make test`,
# whether or not combat.c exists, so the spec cannot quietly go soft. The original
# overnight proof used throwaway models in /var/tmp that were gone by morning and
# could not be re-run — see AGENTS.md § 5 on a control nobody can re-run.
set -uo pipefail

cd "$(dirname "$0")/.." || exit 1
fail=0
ok()   { printf '  PASS  %s\n' "$1"; }
bad()  { printf '  FAIL  %s\n' "$1"; fail=1; }
skip() { printf '  SKIP  %s\n' "$1"; }

WORK=$(mktemp -d "${TMPDIR:-/var/tmp}/u2-cp5.XXXXXX")
trap 'rm -rf "$WORK"' EXIT

# Every harness linked here shares combat_check.c's main, so all three print the
# same summary line: "combat_check: N checks, M failures". That line is the only
# trustworthy check count: the CHECK macro prints on FAILURE only, so counting
# per-check output is structurally impossible (an earlier version grepped for
# '  ok  ' and reported 0 forever). Empty output means no summary line at all.
summary_checks() { sed -n 's/^combat_check: \([0-9]\{1,\}\) checks, [0-9]\{1,\} failures$/\1/p' "$1" | tail -1; }

printf 'engine CP5 spec\n'

# --- 0. the strings this spec asserts on must actually exist -----------------
# Every message below is compared as text, and `strstr(line, "")` always matches:
# an empty literal does not make an assertion fail, it makes it pass while nothing
# is printed. That is not hypothetical — CI has no original/ultimaii.exe, the
# extractor's `run` locators resolved to "" there, and the first death-check run in
# CI failed only because the row-22 assertion happened to be strict enough to
# notice. So the dependency is now stated where it can be checked.
EMPTY_STRINGS=""
for sym in U2_S_IS_DEAD U2_S_KILLED U2_S_EXP_PLUS U2_S_HIT U2_S_MISS \
           U2_S_LEGS_PARALYZED U2_S_ARMS_PARALYZED U2_S_SLEEP_SPELL \
           U2_S_MAGIC_MISSILE U2_S_THIEF_STOLE U2_S_SITE_TOWN U2_S_ENTER; do
    if grep -q "^#define ${sym} \"\"" build/gen_content.h 2>/dev/null; then
        EMPTY_STRINGS="${EMPTY_STRINGS} ${sym}"
    fi
done
if [ -n "$EMPTY_STRINGS" ]; then
    bad "CP5 generated strings are empty — the message assertions below would pass vacuously:${EMPTY_STRINGS}"
else
    ok "CP5 generated strings are non-empty (no assertion can pass on an empty literal)"
fi

# --- 1. the spec is well-formed C (always runs, guards the contract) --------
cc -std=c11 -Wall -Wextra -Werror -Wshadow -Wstrict-prototypes -Wmissing-prototypes \
   -Isrc -fsyntax-only tests/combat_check.c 2>"$WORK/syn.err"
if [ $? -ne 0 ]; then
    bad "CP5 spec did not syntax-check:"
    sed 's/^/        /' "$WORK/syn.err"
else
    ok "CP5 spec syntax-checks clean (C1/C2/C6 contract is well-formed)"
fi

# --- 1b. the controls, always: this is what proves the spec has teeth --------
# A spec that nothing ever implements can pass while being unable to detect the
# very mistake it was written to prevent. So the spec is run against a faithful
# reference model (must be clean) and a deliberately wrong boolean-immunity model
# (must fail) on every run, before combat.c exists at all.
run_model() {
    local m="$1" want="$2"
    if ! cc -std=c11 -Wall -Wextra -Werror -Isrc -Ibuild -o "$WORK/$m" \
            tests/combat_check.c "tests/$m.c" src/core/rng.c src/core/state.c \
            2>"$WORK/$m.build"; then
        bad "CP5 control $m did not build:"
        sed 's/^/        /' "$WORK/$m.build"
        return
    fi
    local rc=0
    "$WORK/$m" > "$WORK/$m.log" 2>&1 || rc=$?
    local summary; summary=$(tail -1 "$WORK/$m.log")
    # Exit code alone cannot tell "every check passed" from "no check ran", and a
    # silent main() would report the faithful control as a pass. Guard the count
    # before the verdict — same class of defect as the old unconditional `exit 0`
    # and the always-zero grep below (AGENTS.md: a gate that cannot go red).
    local n; n=$(summary_checks "$WORK/$m.log")
    if [ "${n:-0}" -eq 0 ]; then
        bad "CP5 control $m executed 0 checks — the spec is not running (last line: ${summary:-<no output>})"
        return
    fi
    if [ "$want" = "pass" ] && [ "$rc" -ne 0 ]; then
        bad "CP5 POSITIVE control failed — the spec itself is wrong, not the future impl ($summary)"
        sed 's/^/        /' "$WORK/$m.log" | head -20
    elif [ "$want" = "fail" ] && [ "$rc" -eq 0 ]; then
        bad "CP5 NEGATIVE control PASSED — the spec has gone soft and cannot catch boolean immunity"
    elif [ "$want" = "pass" ]; then
        ok "CP5 positive control (faithful model): $summary"
    else
        ok "CP5 negative control (boolean-immunity model): $summary"
    fi
}

run_model combat_model_faithful pass
run_model combat_model_boolean_wrong fail

# --- 1c. self-test: prove the zero-check guard can fire ---------------------
# The guards below go red when a run reports 0 checks. That is only worth
# anything if the parser can tell "0 checks" from "no summary line", so build a
# deliberately empty run and check the parse lands on a literal 0. If this ever
# prints FAIL, the guard is broken and every PASS above is unproven.
if [ -x "$WORK/combat_model_faithful" ]; then
    CP5_SPEC_NO_TESTS=1 "$WORK/combat_model_faithful" > "$WORK/zero.log" 2>&1
    z=$(summary_checks "$WORK/zero.log")
    if [ "$z" = "0" ]; then
        ok "CP5 zero-check self-test: guard reads a real 0 ($(tail -1 "$WORK/zero.log"))"
    elif [ -z "$z" ]; then
        bad "CP5 zero-check self-test: summary line did not parse — the 0-check guard cannot be trusted"
    else
        bad "CP5 zero-check self-test: expected 0 checks from the empty run, got '$z'"
    fi
else
    bad "CP5 zero-check self-test: faithful control binary missing, guard unproven"
fi

# --- 1d. the creature table (CP5 W1) ----------------------------------------
# Independent of combat.c: this is the monx -> DS mapping everything else in CP5
# reads from. Runs whether or not combat exists, and takes the real monx31 when
# the player's content is present, because that is the only input that can
# falsify the offset table rather than check the copy.
if cc -std=c11 -Wall -Wextra -Werror -Isrc -Ibuild -o "$WORK/monsters_check" \
        tests/monsters_check.c src/game/monsters.c src/core/world.c src/core/state.c \
        src/core/save.c src/core/rng.c 2>"$WORK/mon.build"; then
    MONREAL=""
    [ -f ../original/monx31 ] && MONREAL="../original/monx31"
    if "$WORK/monsters_check" "$WORK" $MONREAL > "$WORK/mon.out" 2>&1; then
        n=$(sed -n 's/^monsters_check: \([0-9]\{1,\}\) checks.*/\1/p' "$WORK/mon.out")
        if [ "${n:-0}" -eq 0 ]; then
            bad "CP5 creature-table run executed 0 checks — the spec is not running"
        else
            ok "CP5 W1 creature table: monx -> DS mapping ($n checks, $(tail -1 "$WORK/mon.out"))"
        fi
    else
        bad "CP5 creature-table check failed:"
        sed 's/^/        /' "$WORK/mon.out"
    fi
else
    bad "CP5 creature-table harness did not build:"
    sed 's/^/        /' "$WORK/mon.build"
fi

# --- 1f. the wandering spawn (docs/monster-spawn.md 15.4) -------------------
# The selector table was pinned by forcing DS:60 in a live emulator; this is the
# gate that keeps the engine's copy of it honest, plus the spawner's refusals —
# which matter more than its successes, because a wrong refusal rate is a wrong
# monster density and nothing else would notice.
if cc -std=c11 -Wall -Wextra -Werror -Isrc -Ibuild -o "$WORK/wander_check" \
        tests/wander_check.c src/game/monsters.c src/core/world.c src/core/state.c \
        src/core/save.c src/core/rng.c 2>"$WORK/wander.build"; then
    if "$WORK/wander_check" > "$WORK/wander.out" 2>&1; then
        n=$(sed -n 's/^wander_check: \([0-9]\{1,\}\) checks.*/\1/p' "$WORK/wander.out")
        if [ "${n:-0}" -eq 0 ]; then
            bad "CP5 wander run executed 0 checks — the test is not running"
        else
            ok "CP5 wandering spawn: selector table and spawner refusals ($n checks)"
        fi
    else
        bad "CP5 wandering spawn check failed:"
        sed 's/^/        /' "$WORK/wander.out"
    fi
else
    bad "CP5 wandering spawn harness did not build:"
    sed 's/^/        /' "$WORK/wander.build"
fi

# --- 1e. the attack (CP5 W3) ------------------------------------------------
# Direct test of combat.c, not part of combat_check.c: the attack is implemented,
# so it is tested against the real thing rather than specified against fixtures.
if cc -std=c11 -Wall -Wextra -Werror -Isrc -Ibuild -o "$WORK/attack_check" \
        tests/attack_check.c src/game/combat.c src/game/monsters.c \
        src/core/rng.c src/core/state.c 2>"$WORK/atk.build"; then
    if "$WORK/attack_check" > "$WORK/atk.out" 2>&1; then
        n=$(sed -n 's/^attack_check: \([0-9]\{1,\}\) checks.*/\1/p' "$WORK/atk.out")
        if [ "${n:-0}" -eq 0 ]; then
            bad "CP5 attack run executed 0 checks — the test is not running"
        else
            ok "CP5 W3 attack: hit roll, damage, kill, BCD rewards ($n checks, $(tail -1 "$WORK/atk.out"))"
        fi
    else
        bad "CP5 attack check failed:"
        sed 's/^/        /' "$WORK/atk.out"
    fi
else
    bad "CP5 attack harness did not build:"
    sed 's/^/        /' "$WORK/atk.build"
fi

# --- 1f. the death tail (CP5 W8) -------------------------------------------
# asm/0C62..0C99 as one span, checked against the captured frame in
# captures/spice86/cp5-weak-fight/death1.png. It links the whole game core rather
# than one file because the tail prints through the seam and repaints the status
# band, and a stub of either would let the test pass on a half-implemented death.
if cc -std=c11 -Wall -Wextra -Werror -Isrc -Ibuild -o "$WORK/death_check" \
        tests/death_check.c src/core/*.c src/game/*.c src/debug/*.c 2>"$WORK/death.build"; then
    if "$WORK/death_check" > "$WORK/death.out" 2>&1; then
        n=$(sed -n 's/^death_check: \([0-9]\{1,\}\) checks.*/\1/p' "$WORK/death.out")
        if [ "${n:-0}" -eq 0 ]; then
            bad "CP5 death run executed 0 checks — the test is not running"
        else
            ok "CP5 W8 death: zero DS:51..59, repaint, '<NAME> IS DEAD!' ($n checks, $(tail -1 "$WORK/death.out"))"
        fi
    else
        bad "CP5 death check failed:"
        sed 's/^/        /' "$WORK/death.out"
    fi
else
    bad "CP5 death harness did not build:"
    sed 's/^/        /' "$WORK/death.build"
fi

# --- 1g. the creature turn (CP5 W6/W6b) -------------------------------------
# asm/0A6D..0AB5 and asm/2122..2260. Links the whole game core for the same
# reason the death check does: the turn prints, rolls, and moves bytes that the
# renderer and the passability test both read.
if cc -std=c11 -Wall -Wextra -Werror -Isrc -Ibuild -o "$WORK/ai_check" \
        tests/ai_check.c src/core/*.c src/game/*.c src/debug/*.c 2>"$WORK/ai.build"; then
    if "$WORK/ai_check" > "$WORK/ai.out" 2>&1; then
        n=$(sed -n 's/^ai_check: \([0-9]\{1,\}\) checks.*/\1/p' "$WORK/ai.out")
        if [ "${n:-0}" -eq 0 ]; then
            bad "CP5 creature-turn run executed 0 checks — the test is not running"
        else
            ok "CP5 W6/W6b creature turn: pursue, flee, species gate, specials ($n checks, $(tail -1 "$WORK/ai.out"))"
        fi
    else
        bad "CP5 creature-turn check failed:"
        sed 's/^/        /' "$WORK/ai.out"
    fi
else
    bad "CP5 creature-turn harness did not build:"
    sed 's/^/        /' "$WORK/ai.build"
fi

# --- 1g2. the speed model (asm/06ED rescale, F7/F8) ---------------------------
# The control is a live memory dump, not a hand-written expectation: captures/spice86/
# g30-clockcal/ gives DS:74, DS:554 and the DS:558 multiplier table, and the engine must
# reproduce the DS:580 slots the original had actually stored. Model only -- nothing in
# the engine calls it yet, because what each of the 20 slots gates is still unknown.
if cc -std=c11 -Wall -Wextra -Werror -Isrc -Ibuild -o "$WORK/speed_check" \
        tests/speed_check.c src/core/*.c src/game/*.c src/debug/*.c 2>"$WORK/speed.build"; then
    if "$WORK/speed_check" > "$WORK/speed.out" 2>&1; then
        n=$(sed -n 's/^speed_check: \([0-9]\{1,\}\) checks.*/\1/p' "$WORK/speed.out")
        if [ "${n:-0}" -eq 0 ]; then
            bad "CP5 speed run executed 0 checks — the test is not running"
        else
            ok "CP5 speed model: rescale reproduces the live dump, F7/F8 bounds ($n checks, $(tail -1 "$WORK/speed.out"))"
        fi
    else
        bad "CP5 speed check failed:"
        sed 's/^/        /' "$WORK/speed.out"
    fi
else
    bad "CP5 speed harness did not build:"
    sed 's/^/        /' "$WORK/speed.build"
fi

# --- 1h. the world-map site gate (towns) ------------------------------------
# asm/3389_cmd_E's dispatch. The table is checked on its own and, when the player's
# content is present, against every gate cell in every world sector: each must name
# a sector file that exists. Without a content dir the data half SKIPs and the
# table half still runs.
if cc -std=c11 -Wall -Wextra -Werror -Isrc -Ibuild -o "$WORK/site_check" \
        tests/site_check.c src/core/*.c src/game/*.c src/debug/*.c 2>"$WORK/site.build"; then
    SITEDATA=""
    for d in ../original ../../original; do
        [ -f "$d/mapx00" ] && SITEDATA="$d" && break
    done
    if "$WORK/site_check" $SITEDATA > "$WORK/site.out" 2>&1; then
        n=$(sed -n 's/^site_check: \([0-9]\{1,\}\) checks.*/\1/p' "$WORK/site.out")
        if [ "${n:-0}" -eq 0 ]; then
            bad "CP5 site-gate run executed 0 checks — the test is not running"
        else
            ok "CP5 site gate: tile -> sector digit, and every gate cell resolves ($n checks, $(tail -1 "$WORK/site.out"))"
        fi
    else
        bad "CP5 site-gate check failed:"
        sed 's/^/        /' "$WORK/site.out"
    fi
else
    bad "CP5 site-gate harness did not build:"
    sed 's/^/        /' "$WORK/site.build"
fi

# --- 2. the behavioural run, only when the combat hook exists ---------------
if [ ! -f src/game/combat.c ]; then
    skip "C1 three independent counters DS:26B/26C/26D (0..15) — needs src/game/combat.c"
    skip "C2 ~75% resist roll on a live item slot (DS:D9/DA/E4) — needs src/game/combat.c"
    skip "C6 theft deletes from the item array, nothing restored — needs src/game/combat.c"
    # Must honour $fail. This branch used to `exit 0` unconditionally, which
    # swallowed every earlier failure in the script — a syntax-check break or a
    # control regression printed FAIL and still reported PASS to CI. A gate that
    # cannot go red is worse than no gate.
    printf '\n'
    if [ "$fail" -eq 0 ]; then
        printf 'CP5 SPEC: PASS (spec landed; combat not implemented — by design)\n'
    else
        printf 'CP5 SPEC: FAIL (controls or spec contract broken; behavioural run skipped)\n'
    fi
    exit "$fail"
fi

cc -std=c11 -Wall -Wextra -Werror -Isrc -Ibuild -o "$WORK/combat_check" \
   tests/combat_check.c src/game/combat.c src/core/rng.c src/core/state.c \
   2>"$WORK/cc.err"
if [ $? -ne 0 ]; then
    bad "CP5 combat harness did not build (combat.c present but does not link):"
    sed 's/^/        /' "$WORK/cc.err"
elif "$WORK/combat_check" > "$WORK/combat.out" 2>&1; then
    # The count is parsed from the summary line and asserted non-zero. A run that
    # executed zero checks used to print "0 checks" and still report PASS, which
    # is indistinguishable from the old cosmetic quirk — the failure mode this
    # line exists to catch.
    n=$(summary_checks "$WORK/combat.out")
    if [ "${n:-0}" -eq 0 ]; then
        bad "CP5 behavioural run executed 0 checks — the spec is not running (last line: $(tail -1 "$WORK/combat.out"))"
    else
        ok "CP5 spec: C1/C2/C6 behaviour ($n checks, $(tail -1 "$WORK/combat.out"))"
    fi
else
    bad "CP5 spec failed:"
    sed 's/^/        /' "$WORK/combat.out"
fi

# --- 3. W9: the fight gate, end to end, with no game files ------------------
# The owner's bar for CP5 is "a rendered fight in the game", which no unit test
# above actually proves: they test combat.c, not the command loop that prints into
# the CMD window. This drives ./u2 the way a player is driven — a key script into
# the real input path, the screen read back — against a synthetic content directory
# built by cp5_fight_seed.py. Cleanroom tiles and engine-authored mapx/monx/PLAYER
# bytes, so it runs in CI where the game files are not present.
# A SKIP here would be a lie, because nothing it needs is optional.
if [ ! -x ./u2 ]; then
    bad "CP5 fight gate: ./u2 is not built — run make before make test"
elif ! python3 tests/cp5_fight_seed.py "$WORK/w9" 2>"$WORK/w9.seed.err"; then
    bad "CP5 fight gate: the synthetic content did not build:"
    sed 's/^/        /' "$WORK/w9.seed.err"
else
    # The save is seeded with agility 0x80, which asm/2E3D makes a guaranteed hit
    # (the roll is rand>>1, so it maxes at 127), and EXP/GOLD at 9999 so the kill
    # reward has to wrap. Both halves are asserted: the line and the wrap.
    printf 'A\n0xf3\n' > "$WORK/w9.keys"
    ./u2 --headless --play-map --cleanroom \
         --data-dir "$WORK/w9/content" --save-dir "$WORK/w9/save" \
         --script "$WORK/w9.keys" --dump-state > "$WORK/w9.out" 2>&1
    W9ALL=$(cat "$WORK/w9.out")   # the whole dump: the CMD lines and the status band
    case "$W9ALL" in
      *"CMD: ATTACK--EAST--HIT!!!"*) ok "CP5 W9: the swing renders as ATTACK--EAST--HIT!!! in the CMD window" ;;
      *) bad "CP5 W9: no HIT line. Screen was:"; printf '%s\n' "$W9ALL" | sed 's/^/        /' ;;
    esac
    case "$W9ALL" in
      *"CMD: KILLED--GOLD+"*"--EXP.+"*) ok "CP5 W9: the kill renders as KILLED--GOLD+n--EXP.+m" ;;
      *) bad "CP5 W9: no KILLED line with both rewards — the creature survived or the reward path is silent" ;;
    esac
    # The BCD wrap the kickoff listed as evidence item 9: 9999 + a reward is not a
    # clamp and not a 16-bit overflow. GOLD and EXP are separate lines, so each is
    # matched on its own rather than with one pattern that could borrow the other's.
    case "$W9ALL" in
      *"EXP.=000"*) ok "CP5 W9: EXP wrapped past 9999 instead of clamping (EXP.=000n)" ;;
      *) bad "CP5 W9: EXP did not wrap — expected EXP.=000n after a kill at 9999" ;;
    esac
    case "$W9ALL" in
      *"GOLD=000"*) ok "CP5 W9: GOLD wrapped past 9999 on the same kill (GOLD=000n)" ;;
      *) bad "CP5 W9: GOLD did not wrap — expected GOLD=000n after a kill at 9999" ;;
    esac

    # Control: with no creature in the sector the same two keys must print MISS and
    # must not print a kill. Without this, a gate that always claimed a hit would
    # look identical above.
    : > "$WORK/w9/content/monx00"
    printf 'A\n0xf3\n' > "$WORK/w9.keys"
    ./u2 --headless --play-map --cleanroom \
         --data-dir "$WORK/w9/content" --save-dir "$WORK/w9/save" \
         --script "$WORK/w9.keys" --dump-state > "$WORK/w9ctl.out" 2>&1
    if grep -q "ATTACK--EAST--MISS" "$WORK/w9ctl.out" \
       && ! grep -q "KILLED--" "$WORK/w9ctl.out"; then
        ok "CP5 W9 control: an empty sector gives MISS and no reward line"
    else
        bad "CP5 W9 control failed: the fight gate would pass with nothing to fight"
        sed 's/^/        /' "$WORK/w9ctl.out"
    fi

    # --- and the fight has to be a fight: the creature must be able to answer ----
    # A plain melee type (0x30, no special) at role 2 — alerted, so it walks in and
    # swings and casts nothing. Six passes and the seeded H.P.=9997 must be lower.
    # This is the only CI proof that the melee chain reaches the screen rather than
    # stopping inside ai.c, which is exactly where it would silently not work.
    python3 tests/cp5_fight_seed.py "$WORK/w9m" >/dev/null 2>&1
    python3 - "$WORK/w9m/content/monx00" <<'PYEOF'
import sys
p = sys.argv[1]
d = bytearray(open(p, 'rb').read())
d[64 + 0] = 40      # hp: too much for the scripted swing to end it in one hit
d[96 + 0] = 0x30    # type: Fighter — a plain melee attacker, no special at all
d[160 + 0] = 2      # role: alerted, so it closes and swings
open(p, 'wb').write(bytes(d))
PYEOF
    for i in 1 2 3 4 5 6; do printf 'SP\n'; done > "$WORK/w9m.keys"
    ./u2 --headless --play-map --cleanroom \
         --data-dir "$WORK/w9m/content" --save-dir "$WORK/w9m/save" \
         --script "$WORK/w9m.keys" --dump-state > "$WORK/w9m.out" 2>&1
    # The seed is H.P.=9997, so "fell below the seed" is exactly "does not read
    # 9997". A pattern is the wrong tool here and the first draft had one.
    HP_LINE=$(grep -oE "H\.P\.=[0-9]{4}" "$WORK/w9m.out" | tail -1)
    if [ -n "$HP_LINE" ] && [ "$HP_LINE" != "H.P.=9997" ]; then
        ok "CP5 W9: a plain melee creature wounds the player — H.P. reads ${HP_LINE#H.P.=}, not the seeded 9997"
    else
        bad "CP5 W9: the melee chain did not reach the screen — H.P. is still 9997 after six turns"
        grep -E "H\.P\.|CMD" "$WORK/w9m.out" | sed 's/^/        /'
    fi
fi

# --- C3: legs paralysis is a movement rejection ----------------------------
# asm/2520 sits inside the passability routine: if DS:26B is set it prints
# "--PARALIZED!" and takes the same reject return an impassable tile uses. The
# counter is reached the only way it is reached in play — a Daemon (type 0x34,
# dispatched by asm/0AD3) casting it during the fight — so no debug seam and no
# cheat flag are needed to gate this.
#
# The control matters more than the case. The same script against an Orc (type
# 0x30, no special at all) must NOT produce the word; without that half this gate
# could not fail, which is the failure mode this project has been bitten by twice.
python3 tests/cp5_fight_seed.py "$WORK/c3" >/dev/null 2>&1
for kind in daemon orc; do
    python3 - "$WORK/c3/content/monx00" "$kind" <<'PYEOF'
import sys
p, kind = sys.argv[1], sys.argv[2]
d = bytearray(open(p, 'rb').read())
d[64 + 0]  = 200                       # hp: it has to survive the whole script
d[96 + 0]  = 0x34 if kind == 'daemon' else 0x30
d[128 + 0] = 0x08
d[160 + 0] = 1                         # role 1: the AI pass that casts specials
open(p, 'wb').write(bytes(d))
PYEOF
    # Interleaved, and many attempts. asm/0C33 ticks once per turn, so a paralysis of at most 15
    # clears within 15 passes -- the old "16 passes then one step" let it expire unseen and the
    # word never printed, which is why this test passed before and failed after the fix. A west
    # attempt has to land inside the short window where the counter is still non-zero, so the
    # attempt count is what makes it observable, not idle time. 0xf2 is U2_KEY_LEFT (platform.h);
    # the script input takes hex tokens verbatim.
    { for i in $(seq 1 60); do printf 'SP\n0xf2\n'; done; } > "$WORK/c3-$kind.keys"
    ./u2 --headless --play-map --cleanroom          --data-dir "$WORK/c3/content" --save-dir "$WORK/c3/save"          --script "$WORK/c3-$kind.keys" --dump-each > "$WORK/c3-$kind.out" 2>&1
done

if grep -q -- "--PARALIZED!" "$WORK/c3-daemon.out"; then
    if grep -q -- "--PARALIZED!" "$WORK/c3-orc.out"; then
        bad "CP5 C3: the control Orc also printed --PARALIZED! — the gate cannot fail"
    else
        ok "CP5 C3: a Daemon's leg paralysis rejects the next step with --PARALIZED!, and a plain melee Orc does not"
    fi
else
    bad "CP5 C3: the Daemon fight never produced --PARALIZED! — the special or the reject is not wired"
    sed 's/^/        /' "$WORK/c3-daemon.out" | tail -6
fi

# C3b: paralysis must EXPIRE, and it must expire on the open world.
# The tick at asm/0C33 is reached by BOTH arms of asm/0C1F: the site branch `jne L_000e33`
# jumps OVER the world-map block and LANDS ON the tick, it does not gate it. An earlier engine
# reading took it as a gate and wrapped the decrement in `if (sector_second != 0)`, which made a
# 0..15 turn paralysis permanent on any sector whose ones digit is 0 -- including sector 00,
# which is exactly this fixture. The owner found it by playing, not by reading.
# Re-apply the Daemon patch: the loop above left the content holding an Orc.
python3 - "$WORK/c3/content/monx00" <<'PYEOF'
import sys
d = bytearray(open(sys.argv[1], 'rb').read())
d[64 + 0] = 200; d[96 + 0] = 0x34; d[128 + 0] = 0x08; d[160 + 0] = 1
open(sys.argv[1], 'wb').write(bytes(d))
PYEOF
{ for i in $(seq 1 60); do printf 'SP\n0xf2\n'; done; } > "$WORK/c3-expire.keys"
./u2 --headless --play-map --cleanroom \
     --data-dir "$WORK/c3/content" --save-dir "$WORK/c3/save" \
     --script "$WORK/c3-expire.keys" --dump-each > "$WORK/c3-expire.out" 2>&1
par=$(grep -c -- "--PARALIZED!" "$WORK/c3-expire.out")
# WHY THERE IS NO AUTOMATED DECAY GATE HERE, stated rather than hidden. An earlier version of this
# block asserted "refusals must be a minority of attempts" as the decay test. It was run against a
# build with the tick deleted entirely and it still PASSED -- 2 of 24 refused either way -- because
# a successful west step walks the player away from the Daemon, so neither build reaches a terminal
# state and the counts cannot separate them. A gate that cannot fail is the failure mode
# AGENTS.md § 3 and § 5 both call out, so the assertion is removed rather than kept for comfort.
#
# What IS gated: that the special reaches play at all (the count above), and that a plain melee
# Orc never produces the word (C3's control half). What is NOT gated: that the counter decays.
# That is established by direct measurement -- a breakpoint on asm/0C33 shows one tick per turn,
# food -10 at every stop -- and by the owner playing the build, not by this script. Making it
# gateable needs a deterministic rig: either a debug seam that sets paral_legs, or a fixture where
# the Daemon cannot be walked away from. Both are engine-surface decisions, not test tweaks.
if [ "$par" -gt 0 ]; then
    ok "CP5 C3b: leg paralysis is applied on the open world (sector 00, $par of 60 attempts refused)"
else
    bad "CP5 C3b: the Daemon never paralyzed on the open world -- the special is not reaching play"
    sed 's/^/        /' "$WORK/c3-expire.out" | tail -5
fi
echo "  NOTE  CP5 C3b: decay is measured (two-arm run on the original), not gated -- see above"

# --- C3c: a refused step is a completed command, so the world takes its turn ----
#
# asm/0A02 (the --INVALID MOVE! reject) falls through to asm/0A15_invalid_move_to_cmd_done,
# which jumps to asm/0A30 and thence into asm/0A33_cmd_done and asm/0A38_post_command_tail.
# So bumping into a wall runs the creature sweep and the wandering-spawn attempt. The engine
# used to `continue` without creature_turn(), which froze our creatures while the player stood
# against a wall while the original's kept moving. Proven from bytes 2026-10-26 and corroborated
# live in sector 03: 16 refused direction keys, creature coordinates changed on 12 of them.
#
# The signature is the turn log. --debug cli writes one dump per RESOLVED turn, and a refused
# step used to resolve nothing, so a build without the fix writes ZERO dumps for a script made
# entirely of refusals. That is what makes this a gate that fails on the behaviour it replaced,
# which is the only kind worth having. The player must also stay put, or the refusals are not
# refusals and the count would pass for the wrong reason.
python3 tests/cp5_fight_seed.py "$WORK/c3c" >/dev/null 2>&1
python3 - "$WORK/c3c/content/mapx00" <<'PYEOF'
import sys
p = sys.argv[1]
d = bytearray(open(p, 'rb').read())
d[0 * 64 + 1] = 0x10          # mountain at (1,0), directly west of the entry at (2,0)
open(p, 'wb').write(bytes(d))
PYEOF
for i in $(seq 1 5); do printf '0xf2\n'; done > "$WORK/c3c.keys"   # 0xf2 = U2_KEY_LEFT
rm -rf "$WORK/c3c/dbg"
./u2 --headless --play-map --cleanroom --data-dir "$WORK/c3c/content" --save-dir "$WORK/c3c/save" \
     --script "$WORK/c3c.keys" --debug cli --debug-path "$WORK/c3c/dbg" --debug-limit 0 \
     >/dev/null 2>&1
dumps=$(find "$WORK/c3c/dbg" -name 'turn-*.json' 2>/dev/null | wc -l)
last=$(find "$WORK/c3c/dbg" -name 'turn-*.json' 2>/dev/null | sort | tail -1)
stay=$(python3 -c "
import json, sys
p = sys.argv[1]
print(json.load(open(p))['state']['raw']['pos'] if p else 'none')" "$last" 2>/dev/null)
if [ "$dumps" -eq 5 ] && [ "$stay" = "02 00" ]; then
    ok "CP5 C3c: a refused step takes the world turn ($dumps dumps for 5 refusals, player held at 02 00)"
else
    bad "CP5 C3c: $dumps dumps for 5 refused steps (expect 5), player at '$stay' (expect '02 00') — the reject path is not taking the world turn"
fi

# --- the jump table is reachable: a letter key must land in its handler ------
# u2_cmd_implemented() reports what the table CLAIMS, and nothing until now proved the
# loop routes a letter into it at all. The Q migration is what exposed the gap: putting a
# handler in the wrong table slot compiles clean, keeps every other gate green, prints
# nothing, and still reports itself as implemented. One run per letter, so a misfiled slot
# names itself instead of arriving as a mystery.
for pair in "H:HYPER WHAT?" "J:JUMP...WHEE..." "Q:ONE MOMENT PLEASE!" "P:CMD: PASS" "Z:A LEVEL" "E:CMD: ENTER WHAT?" "A:CMD: ATTACK--" "U:CMD: UNLOCK DIRECTION-" "M:MAGIC SPELL READY #1"; do
    letter=${pair%%:*}; want=${pair#*:}
    python3 tests/cp5_fight_seed.py "$WORK/tab-$letter" >/dev/null 2>&1
    # Two of these block for a second key inside the handler: Z waits for a dismissing key,
    # M waits for a spell number. Z is given NO dismiss key on purpose: the original blocks with
    # the page on screen, so an undismissed Z leaves the page as the final state and that is the
    # only moment the page is observable from a scripted run. The dismiss path is gated separately
    # below, where the assertion is that the screen comes back clean.
    case "$letter" in
      Z) printf 'Z
' > "$WORK/tab-$letter.keys" ;;
      M) printf 'M\n1\n'  > "$WORK/tab-$letter.keys" ;;
      *) printf '%s\n' "$letter" > "$WORK/tab-$letter.keys" ;;
    esac
    ./u2 --headless --play-map --cleanroom \
         --data-dir "$WORK/tab-$letter/content" --save-dir "$WORK/tab-$letter/save" \
         --script "$WORK/tab-$letter.keys" --dump-state > "$WORK/tab-$letter.out" 2>&1
    if grep -qF -- "$want" "$WORK/tab-$letter.out"; then
        ok "dispatch: letter $letter reaches its handler in cmd_table ($want on screen)"
    else
        bad "dispatch: $letter printed nothing — the slot is empty, misfiled, or the loop is not calling u2_cmd_dispatch"
        sed 's/^/        /' "$WORK/tab-$letter.out" | tail -5
    fi
done

# Z takes the WHOLE screen. asm/4568 opens with `call L_004c1c`, a full clear, so the original's
# Z page has no status band on it at all -- proven against the original with the same maxed save
# in captures/spice86/z-page-maxed/readings.md. The engine used to leave the band in place, so a
# character owning many items had its ITEMS list run into GOLD= and overwrite H.P./FOOD/EXP..
# The old Z assertion only checked "A LEVEL" at the top, which is why it shipped: the defect was
# entirely below the line the test looked at.
if grep -qE "H\.P\.=|FOOD=|EXP\.=" "$WORK/tab-Z.out"; then
    bad "regression: the Z page still draws the status band -- asm/4568 clears the whole screen"
    grep -nE "H\.P\.=|FOOD=|EXP\.=" "$WORK/tab-Z.out" | head -3 | sed 's/^/        /'
else
    ok "Z page is a full-screen takeover: no status band, matching asm/4568's clear"
fi

# ...and the overlay has to come back DOWN clean. Z draws into the persistent text grid, which is
# the same grid the compositor reads for the status band and the CMD prompt, so the handler snapshots
# the grid and puts the snapshot back on a real keypress. Before that, u2_overworld_draw composited
# vram rows 20..24 without clearing them and the tail of the ITEMS list stayed printed over the band
# -- the owner saw `UMS-01 PASS` / `TRI-LITHI` stuck under the map with no H.P. line anywhere.
# Headless could not show the layering, and this is the half that leaves the screen sane.
python3 tests/cp5_fight_seed.py "$WORK/z-restore" >/dev/null 2>&1
printf 'Z\nSP\n' > "$WORK/z-restore.keys"
./u2 --headless --play-map --cleanroom --data-dir "$WORK/z-restore/content" \
     --save-dir "$WORK/z-restore/save" --script "$WORK/z-restore.keys" \
     --dump-state > "$WORK/z-restore.out" 2>&1
if grep -qE "H\.P\.=|FOOD=" "$WORK/z-restore.out"; then
    ok "a keypress dismisses the Z page and the status band comes back"
else
    bad "regression: after dismissing Z the status band never returns"
    sed 's/^/        /' "$WORK/z-restore.out" | tail -6
fi
# The stronger property, and the one the owner actually asked for: the overlay leaves NO trace.
# Comparing against a run that never opened Z proves the screen is restored rather than plausibly
# re-drawn. This is the gate that survives the failure mode the text-grep version did not: with the
# teardown removed the leftover shows up as the page still being up, not as stray item text, so
# grepping for item names passed a broken build. Verified as a control -- with the restore removed
# this diff goes non-empty.
printf 'S\n' > "$WORK/z-baseline.keys"
printf 'Z\nx\nS\n' > "$WORK/z-trace.keys"
./u2 --headless --play-map --cleanroom --data-dir "$WORK/z-restore/content" \
     --save-dir "$WORK/z-restore/save" --script "$WORK/z-baseline.keys" \
     --dump-state 2>&1 | grep '^|' > "$WORK/z-baseline.out"
./u2 --headless --play-map --cleanroom --data-dir "$WORK/z-restore/content" \
     --save-dir "$WORK/z-restore/save" --script "$WORK/z-trace.keys" \
     --dump-state 2>&1 | grep '^|' > "$WORK/z-trace.out"
if diff -q "$WORK/z-baseline.out" "$WORK/z-trace.out" >/dev/null; then
    ok "Z leaves no trace: post-dismiss screen is byte-identical to a run that never opened Z"
else
    bad "regression: the Z overlay is still visible after dismissal"
    diff "$WORK/z-baseline.out" "$WORK/z-trace.out" | head -8 | sed 's/^/        /'
fi

# M's second half: the echo is the spell NAME, not a number. That is the whole point of the
# 2026-10-25 correction to asm/3B92_cmd_M.asm, so it gets its own assertion — and it is
# mode-aware, because with no copy of the game the pool names are blank by design (see
# status.c's Z_NAME) and only the prompt half is checkable.
if grep -q "U2_T_SPELLS_N" build/gen_content.h 2>/dev/null; then
    if grep -qF -- "READY => LIGHT" "$WORK/tab-M.out"; then
        ok "dispatch: cmd_M echoes the spell NAME from the pool (READY => LIGHT, not a digit)"
    else
        bad "dispatch: cmd_M did not echo the pool name for slot 1 — expected LIGHT"
        sed 's/^/        /' "$WORK/tab-M.out" | tail -5
    fi
else
    ok "dispatch: cmd_M pool-name assertion skipped with the pool absent (prompt half already passed)"
fi

# --- no quit key, and --dev is the only thing allowed to add one -------------------------
# The original has no quit key anywhere: nothing in asm/ compares against 0x1b (Escape) or
# 0x11 (Ctrl-Q). An earlier revision broke the loop on Escape and had cmd_Z return a quit code
# on it, both as --play-map conveniences, which read as fidelity and were not the game. Those
# are gone; --dev is the sanctioned home, and the rule on it is that it may add observation and
# an exit and may NEVER change game behaviour.
#
# These are behavioural, not greps. --dump-each prints one dump per key, so "did the run
# survive this key" is countable: two PASS lines means both P's ran, one means the key between
# them ended the loop.
quit_count() {   # $1 = extra flags, $2 = key script
    ./u2 --headless $1 --play-map --cleanroom \
         --data-dir "$WORK/quit/content" --save-dir "$WORK/quit/save" \
         --script "$2" --dump-each 2>&1 | grep -c "CMD: PASS"
}
python3 tests/cp5_fight_seed.py "$WORK/quit" >/dev/null 2>&1
printf 'P\nESC\nP\n'     > "$WORK/quit-esc.keys"
printf 'P\n0x11\nP\n'    > "$WORK/quit-ctrlq.keys"

if [ "$(quit_count '' "$WORK/quit-esc.keys")" = "2" ]; then
    ok "no quit key: Escape in the overworld is an ordinary key, the run continues"
else
    bad "regression: Escape ended the overworld run -- the original has no quit key"
fi
if [ "$(quit_count '--dev' "$WORK/quit-esc.keys")" = "2" ]; then
    ok "--dev does not make Escape special either"
else
    bad "--dev must not restore the Escape quit; only Ctrl-Q is gated on --dev"
fi
if [ "$(quit_count '' "$WORK/quit-ctrlq.keys")" = "2" ]; then
    ok "Ctrl-Q is inert without --dev: default mode implements the game and nothing else"
else
    bad "Ctrl-Q ended the run without --dev -- dev affordance leaked into the default path"
fi
if [ "$(quit_count '--dev' "$WORK/quit-ctrlq.keys")" = "1" ]; then
    ok "--dev: Ctrl-Q ends the run (the development exit the owner asked for, on a free byte)"
else
    bad "--dev: Ctrl-Q did not end the run -- the dev exit is not wired"
fi

# Structural half: a command HANDLER must never be able to end the session at all, in any mode.
# That is where the Escape version went wrong, and a behaviour test would not catch it coming
# back inside cmd_Z if the loop grew another path.
if grep -rq "U2_CMD_QUIT" src/ 2>/dev/null; then
    bad "regression: a command-level quit path is back in src/ -- handlers must not end sessions"
    grep -rn "U2_CMD_QUIT" src/ | head -3 | sed 's/^/        /'
else
    ok "no command handler can end the session, in any mode"
fi

# --- W and V: wear armour and view, all three refusal branches --------------
# cmd_W was static-only until 2026-10-26 and cmd_V's render is still not modelled, so the gate
# asserts the parts that ARE established: the menu, the armour-name echo, and each exit. The name
# echo matters — the original prints "CLOTH READY." as one line, and an engine that skipped the
# pool print would still print "READY." and look fine to a test that only greps for it.
python3 tests/cp5_fight_seed.py "$WORK/wv" >/dev/null 2>&1
patch_player() {   # patch_player FILE OFFSET VALUE   (file[i] == DS[0x36+i])
    python3 - "$1" "$2" "$3" <<'PYEOF'
import sys
p, off, val = sys.argv[1], int(sys.argv[2], 0), int(sys.argv[3], 0)
d = bytearray(open(p, 'rb').read())
d[off] = val
open(p, 'wb').write(bytes(d))
# Verify the write landed. A helper that fails and exits non-zero while the shell carries on is the
# exact silent-failure shape this project keeps recording: the first version of this function used
# int() on a 0x-prefixed value, raised ValueError, patched nothing, and the strength-gate assertion
# below failed for a reason that had nothing to do with the engine.
if bytearray(open(p, 'rb').read())[off] != val:
    sys.exit(f'patch_player: write to {off} did not land')
PYEOF
}
PLAYER="$WORK/wv/save/PLAYER"
run_wv() {   # run_wv EXTRA_FLAGS SCRIPT OUTFILE
    ./u2 --headless $1 --play-map --cleanroom --data-dir "$WORK/wv/content" \
         --save-dir "$WORK/wv/save" --script "$2" --dump-each > "$3" 2>&1
}

# (a) own CLOTH, strong enough -> name then READY.   DS:97 -> file 0x61, DS:4B -> file 0x15
patch_player "$PLAYER" $((0x61)) 1
patch_player "$PLAYER" $((0x15)) 0x40
printf 'W\n1\n' > "$WORK/wv-ok.keys"
run_wv "" "$WORK/wv-ok.keys" "$WORK/wv-ok.out"
if grep -q "CLOTH READY\." "$WORK/wv-ok.out"; then
    ok "CP5 W/V: WEAR ARMOUR echoes the armour NAME from the pool before READY."
else
    bad "CP5 W/V: expected 'CLOTH READY.' — the pool echo or the success path is broken"
    sed 's/^/        /' "$WORK/wv-ok.out" | tail -5
fi

# (b) own nothing -> the menu still lists all six, and the refusal names the type
patch_player "$PLAYER" $((0x61)) 0
printf 'W\n2\n' > "$WORK/wv-no.keys"
run_wv "" "$WORK/wv-no.keys" "$WORK/wv-no.out"
if grep -q "LEATHER NOT OWNED!" "$WORK/wv-no.out"; then
    ok "CP5 W/V: unowned armour is refused AFTER the choice, naming the type"
else
    bad "CP5 W/V: expected 'LEATHER NOT OWNED!'"
    sed 's/^/        /' "$WORK/wv-no.out" | tail -5
fi

# (c) own it but too weak. digit*8 vs the PACKED byte: 1*8 >= 0x08 refuses.
patch_player "$PLAYER" $((0x61)) 1
patch_player "$PLAYER" $((0x15)) 0x08
printf 'W\n1\n' > "$WORK/wv-weak.keys"
run_wv "" "$WORK/wv-weak.keys" "$WORK/wv-weak.out"
if grep -q "STRONG ENOUGH TO WEAR!" "$WORK/wv-weak.out"; then
    ok "CP5 W/V: the strength gate refuses against the packed strength byte, not the decimal"
else
    bad "CP5 W/V: expected 'STRONG ENOUGH TO WEAR!' with DS:4B = 0x08"
    sed 's/^/        /' "$WORK/wv-weak.out" | tail -5
fi
patch_player "$PLAYER" $((0x15)) 0x40

# (d) enhanced lists only what is owned; fidelity lists all six.
printf 'W\n1\n' > "$WORK/wv-enh.keys"
run_wv "--enhanced" "$WORK/wv-enh.keys" "$WORK/wv-enh.out"
if grep -q "6-POWER" "$WORK/wv-enh.out"; then
    bad "CP5 W/V: enhanced mode still lists unowned armour (found 6-POWER)"
else
    ok "CP5 W/V: enhanced mode lists only owned armour, keeping the original numbering"
fi
if grep -q "1-CLOTH" "$WORK/wv-enh.out"; then
    ok "CP5 W/V: the owned entry keeps menu number 1, so the digit still indexes the table"
else
    bad "CP5 W/V: enhanced mode dropped the owned CLOTH entry or renumbered it"
fi

# (e) V with no helm held -> VIEW WHAT?. items_held[5] is DS:DB; U2_T_ITEMS[5] is HELM.
printf 'V\n' > "$WORK/wv-v.keys"
run_wv "" "$WORK/wv-v.keys" "$WORK/wv-v.out"
if grep -q "VIEW WHAT?" "$WORK/wv-v.out"; then
    ok "CP5 W/V: VIEW with no HELM held prints VIEW WHAT?"
else
    bad "CP5 W/V: expected 'VIEW WHAT?' with an empty inventory"
    sed 's/^/        /' "$WORK/wv-v.out" | tail -5
fi

printf '\n'
if [ "$fail" -eq 0 ]; then
    printf 'CP5 SPEC: PASS\n'
else
    printf 'CP5 SPEC: FAIL\n'
fi
exit "$fail"
