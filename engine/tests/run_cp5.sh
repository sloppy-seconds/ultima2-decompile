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

printf '\n'
if [ "$fail" -eq 0 ]; then
    printf 'CP5 SPEC: PASS\n'
else
    printf 'CP5 SPEC: FAIL\n'
fi
exit "$fail"
