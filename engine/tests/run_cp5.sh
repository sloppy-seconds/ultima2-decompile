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
    # 16 turns of space to let the Daemon close and cast, then one west step.
    # 0xf2 is U2_KEY_LEFT (platform.h); the script input takes hex tokens verbatim.
    { for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16; do printf 'SP\n'; done
      printf '0xf2\n'; } > "$WORK/c3-$kind.keys"
    ./u2 --headless --play-map --cleanroom          --data-dir "$WORK/c3/content" --save-dir "$WORK/c3/save"          --script "$WORK/c3-$kind.keys" --dump-state > "$WORK/c3-$kind.out" 2>&1
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

printf '\n'
if [ "$fail" -eq 0 ]; then
    printf 'CP5 SPEC: PASS\n'
else
    printf 'CP5 SPEC: FAIL\n'
fi
exit "$fail"
