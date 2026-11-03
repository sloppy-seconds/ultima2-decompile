#!/usr/bin/env bash
# Prove the space gate can go red where it enforces it.
#
# A checker that returns a wrong verdict is worse than a tool that returns a wrong
# answer, so every mutant is run from the same directory and the same build the
# real gate uses, and the clean run must also be asserted green — a selftest that
# only checks the mutants can pass while the gate itself is broken.
set -u
cd "$(dirname "$0")/.." || exit 1

WORK=$(mktemp -d /var/tmp/u2-space-selftest.XXXXXX)
trap 'rm -rf "$WORK"' EXIT

cc -std=c11 -Wall -Wextra -Werror -Isrc -o "$WORK/space_check" \
   tests/space_check.c src/game/space.c 2>"$WORK/cc.err"
if [ $? -ne 0 ]; then
    echo "SPACE SELFTEST: FAIL — harness did not build"
    head -5 "$WORK/cc.err"
    exit 1
fi

fails=0
total=0

# The clean run must pass, or the mutants prove nothing.
total=$((total+1))
if "$WORK/space_check" >"$WORK/clean.out" 2>&1; then
    echo "  ok    clean run passes ($(grep -c '  PASS  ' "$WORK/clean.out") checks)"
else
    echo "  BAD   clean run FAILED — the gate is broken, not the mutants"
    sed 's/^/          /' "$WORK/clean.out" | tail -5
    fails=$((fails+1))
fi

for m in gate-pre earth-00 tile-any step-4; do
    total=$((total+1))
    if "$WORK/space_check" --mutant "$m" >/dev/null 2>&1; then
        echo "  BAD   mutant $m was not caught — the gate cannot fail on it"
        fails=$((fails+1))
    else
        echo "  ok    mutant $m caught"
    fi
done

# A control that must stay quiet: an unknown mutant is a usage error (exit 2),
# not a silent pass.
total=$((total+1))
"$WORK/space_check" --mutant nonsense >/dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "  BAD   an unknown mutant exited 0"
    fails=$((fails+1))
else
    echo "  ok    unknown mutant refuses instead of passing"
fi

if [ "$fails" -ne 0 ]; then
    echo "SPACE SELFTEST: FAIL ($fails of $total)"
    exit 1
fi
echo "SPACE SELFTEST: PASS ($total controls)"
