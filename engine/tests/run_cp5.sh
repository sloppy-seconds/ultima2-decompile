#!/usr/bin/env bash
# tests/run_cp5.sh — CP5 combat acceptance SPEC (tickets C1, C2, C6).
#
# CP5 is scoped but NOT started (docs/phase4-state.md § CP5), and the overnight
# contract forbids implementing combat unattended. So this runner does two things:
#
#   1. Always syntax-check tests/combat_check.c, so the specification is proven
#      to be well-formed C and its API contract is pinned even while the engine
#      has no combat module. This runs in CI.
#   2. Run the behavioural spec only when src/game/combat.c exists. Until then
#      each ticket is reported SKIP with the exact missing hook named, and the
#      suite stays green (a skipped spec must not turn the gate red).
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
    ok "CP5 spec: C1/C2/C6 behaviour ($(grep -c '  ok  ' "$WORK/combat.out") checks, $(tail -1 "$WORK/combat.out"))"
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
