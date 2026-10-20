#!/usr/bin/env bash
# tests/run_cp0.sh — CP0 acceptance test.
#
#   make && ./u2 --headless --script tests/title.keys --dump-state
#
# prints a screen grid + JSON and exits 0. This script re-checks that claim
# objectively: exit status, grid present, JSON parses, the seam probes ran,
# the run is reproducible, and --trace cites asm addresses.
set -uo pipefail

cd "$(dirname "$0")/.." || exit 1
fail=0
ok()   { printf '  PASS  %s\n' "$1"; }
bad()  { printf '  FAIL  %s\n' "$1"; fail=1; }

SCRIPT="tests/selftest.keys"
ARGS=(--headless --selftest --script "$SCRIPT" --dump-state)

printf 'engine CP0 test\n'

out1=$(./u2 "${ARGS[@]}")
rc=$?

[ "$rc" = "0" ] && ok "exit status 0" || bad "exit status $rc"

printf '%s\n' "$out1" | grep -q 'CP0 SKELETON' \
    && ok "screen grid rendered (banner row present)" \
    || bad "banner row missing"

printf '%s\n' "$out1" | grep -q 'rand_byte(5217)' \
    && ok "rand_byte seam exercised" || bad "rand_byte probe missing"

printf '%s\n' "$out1" | grep -q 'speaker_freq(5CD2)' \
    && ok "speaker_freq seam exercised" || bad "speaker_freq probe missing"

printf '%s\n' "$out1" | grep -q '"engine"' \
    && ok "state dump emitted" || bad "state dump missing"

printf '%s\n' "$out1" | sed -n '/^{/,$p' | python3 -c '
import json,sys
d=json.load(sys.stdin)
assert d["mode"]=="headless", d["mode"]
assert d["screen"]["cols"]==40 and d["screen"]["rows"]==25, d["screen"]
assert d["platform"]["renderer"]=="null", d["platform"]
assert d["platform"]["input"]=="script", d["platform"]
assert "state" in d and "rng" in d["state"], d
' >/dev/null 2>&1 \
    && ok "JSON parses with the expected schema" \
    || bad "JSON does not parse or schema mismatch"

out2=$(./u2 "${ARGS[@]}")
[ "$out1" = "$out2" ] && ok "headless run is reproducible (two runs identical)" \
                      || bad "headless run differs between runs"

tr=$(mktemp "${TMPDIR:-/var/tmp}/u2-cp0-trace.XXXXXX")
./u2 "${ARGS[@]}" --trace="$tr" >/dev/null
grep -q 'seam=str_out_at asm=51EB' "$tr" && grep -q 'seam=rand_byte asm=5217' "$tr" \
    && ok "--trace logs seam calls with asm citations" \
    || bad "--trace output missing or uncited"
rm -f "$tr"

# The PRNG is a shift register (asm/5217 + asm/522B + asm/5236), seeded once at
# launch from the 0x40:6C byte (asm/0100). Vector derived by hand-decoding those
# three fragments together; it guards regressions and documents the decode.
vec=$(./u2 --rng-sequence 14)
[ "$vec" = "2,3,4,6,10,16,24,35,52,79,120,180,12,144" ] \
    && ok "rand_byte sequence matches the decoded shift register" \
    || bad "rand_byte sequence is $vec"

vec2=$(./u2 --seed 0x20 --rng-sequence 6)
[ "$vec2" = "98,163,228,39,171,178" ] \
    && ok "--seed changes the sequence as the seed model predicts" \
    || bad "--seed 0x20 gave $vec2"

# The engine must never touch the Phase 3 tree.
if git rev-parse --git-dir >/dev/null 2>&1; then
    dirty=$(git status --porcelain -- ../asm ../original ../references 2>/dev/null)
    [ -z "$dirty" ] && ok "asm/, original/, references/ untouched" \
                   || bad "protected paths dirty: $dirty"
fi

[ "$fail" = "0" ] && { echo "CP0 TEST: PASS"; exit 0; } || { echo "CP0 TEST: FAIL"; exit 1; }
