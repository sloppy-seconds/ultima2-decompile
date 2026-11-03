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

# Resuming the register from a captured state (docs/plan-cross-game-replay.md phase 2).
# asm/0100 can only reach 256 of 2^48 register states, so a replay that has to pick up mid-session
# needs a raw load. The harness carries its own corrupt-register control: a load that silently did
# nothing would still "roll something", and that is the failure this has to catch.
if cc -std=c11 -Wall -Wextra -Werror -Isrc -Icontent -o "${WORK:-/var/tmp}/rng_check" \
        tests/rng_check.c src/core/rng.c src/core/state.c 2>"${WORK:-/var/tmp}/rng.build"; then
    if "${WORK:-/var/tmp}/rng_check" > "${WORK:-/var/tmp}/rng.out" 2>&1; then
        n=$(sed -n 's/^rng_check: \([0-9]\{1,\}\) checks.*/\1/p' "${WORK:-/var/tmp}/rng.out")
        if [ "${n:-0}" -eq 0 ]; then
            bad "CP0 rng resume run executed 0 checks — the test is not running"
        else
            ok "CP0 rng resume: load reproduces the stream, controls fire ($n checks)"
        fi
    else
        bad "CP0 rng resume check failed:"
        sed 's/^/        /' "${WORK:-/var/tmp}/rng.out"
    fi
else
    bad "CP0 rng resume harness did not build:"
    sed 's/^/        /' "${WORK:-/var/tmp}/rng.build"
fi

# --trace-rolls: the per-site roll log the roll-allocation diagnosis depends on.
# It must be non-empty, numbered from 1, and strictly increasing — a trace that silently stopped
# numbering would read exactly like "no rolls happened", which is the failure shape this project
# keeps meeting. The named sites are what make it more than a count.
rt="${WORK:-/var/tmp}/cp0-rolls.txt"
if ./u2 "${ARGS[@]}" --trace-rolls "$rt" >/dev/null 2>&1 && [ -s "$rt" ]; then
    bad=$(awk 'NR != $1 { print NR; exit }' "$rt")
    sites=$(awk '{print $2}' "$rt" | sort -u | wc -l)
    if [ -z "$bad" ] && [ "$sites" -ge 1 ]; then
        ok "--trace-rolls: $(wc -l < "$rt") rolls logged from $sites distinct call sites, numbered from 1"
    else
        bad "--trace-rolls numbering broken at line ${bad:-?} or no sites recorded"
    fi
else
    bad "--trace-rolls produced no output (or the fixture run failed)"
fi

# --rng-state must reject malformed input rather than quietly defaulting: a mis-parsed register makes
# a resumed replay diverge for a reason that looks like an engine bug.
if ./u2 --rng-state 8282ff --rng-sequence 3 >/dev/null 2>&1; then
    bad "--rng-state 8282ff was accepted; a short register must exit non-zero"
else
    ok "--rng-state rejects a short register (exit non-zero, not a silent default)"
fi
if ./u2 --rng-state 8282ffc7cdzz --rng-sequence 3 >/dev/null 2>&1; then
    bad "--rng-state with non-hex was accepted"
else
    ok "--rng-state rejects non-hex input"
fi

base_seq=$(./u2 --rng-sequence 6)
loaded_seq=$(./u2 --rng-state 8282ffc7cda4 --rng-sequence 6)
if [ -n "$loaded_seq" ] && [ "$loaded_seq" != "$base_seq" ]; then
    ok "--rng-state changes the sequence (default $base_seq -> loaded $loaded_seq)"
else
    bad "--rng-state did not change the sequence: base=$base_seq loaded=$loaded_seq"
fi

# The engine must never change the bytes the reconstruction produces.
#
# original/ and references/ are game content: they must be untouched, full stop.
#
# asm/ is different. Per AGENTS.md § 3 the asm tree IS the project's one
# lookup table for address -> behaviour, so discovering a name REQUIRES renaming
# an asm file and editing its header in the same commit. A blanket "asm/ must be
# clean" guard therefore blocks the rule it was meant to protect. What actually
# has to be invariant is the ASSEMBLABLE CONTENT, so that is what is checked
# here: comment lines (leading '#') may change, everything else may not.
#
# The check is deliberately NOT per-file. A per-file md5 plus "no deletions" was
# correct while the only legal asm/ edit was a rename, and it became actively
# wrong the first time function boundaries moved: merging seven fragments into one
# routine deletes six files, and the old guard reported that as vandalism. The
# conserved quantity is the whole tree's body content, ordered by each file's
# declared start address -- which renames, merges and splits all preserve and which
# any body edit breaks. See engine/tests/asm_body_guard.py.
# The end-to-end case is covered independently by tools/assemble_clean.sh, which
# rebuilds the whole binary and compares it against the known md5.
if git rev-parse --git-dir >/dev/null 2>&1; then
    dirty=$(git status --porcelain -- ../original ../references 2>/dev/null)
    [ -z "$dirty" ] && ok "original/ and references/ untouched" \
                   || bad "protected paths dirty: $dirty"

    # The guard compares a tree to a ref. With no base it uses HEAD, which on a clean
    # checkout means comparing HEAD to itself -- a PASS that checked nothing. The guard
    # now exits 2 when it spots that, and CP0 reports it as a SKIP rather than a pass or
    # a false "content changed". The real CI check lives in .github/workflows/
    # asm-checksum.yml, which passes the merge base. Set ASM_GUARD_BASE to do the same
    # here (e.g. before a rebase, ASM_GUARD_BASE=origin/main make -C engine test).
    guard_rc=0
    guard=$(python3 tests/asm_body_guard.py ${ASM_GUARD_BASE:+--base "$ASM_GUARD_BASE"} 2>&1) || guard_rc=$?
    case "$guard_rc" in
        0) ok "$guard" ;;
        2) echo "  SKIP  asm/ body guard: $guard" ;;
        *) bad "asm/ body content changed: $(printf '%s' "$guard" | tr '\n' ' ')" ;;
    esac
fi

# --- renderer selection: a flag that cannot be honoured must refuse ----------
# This is the terminal (cc-only) build, so --renderer=sdl is a request this binary
# cannot serve. It used to be ignored in silence, which made the wrong binary plus
# the right flag look exactly like a window that failed to open -- and that is how
# a player meets it now that the SDL build defaults to the window. Every branch
# here is a control for itself: a wrong exit code fails the gate.
if ./u2 --renderer=sdl --headless --script "$SCRIPT" >/dev/null 2>"${WORK:-/var/tmp}/cp0-renl.err"; then
    bad "--renderer=sdl was accepted by a build with no SDL backend"
else
    grep -q "without an SDL backend" "${WORK:-/var/tmp}/cp0-renl.err" \
        && ok "--renderer=sdl in a non-SDL build refuses and says why" \
        || bad "--renderer=sdl failed, but not with the message a player can act on"
fi

if ./u2 --renderer=bogus >/dev/null 2>&1; then
    bad "--renderer=bogus was accepted"
else
    ok "--renderer rejects a value it does not implement"
fi

### --- --version: a binary has to say what it is -------------------------------
# docs/sdl2-vs-sdl3.md § 7: a dev build and a shipped build can be built against
# different implementations of the same SDL2 API, both run, and nothing else about
# them distinguishes them. Every argument in that document would have been a
# one-line answer with this flag present, so the flag is the thing being gated.
# "unstamped" is checked for by name: if the Makefile ever stops passing the -D
# flags, the fallbacks in core/version.c keep it compiling and the binary quietly
# becomes unidentifiable, which is the silent version of this failure.
if ver=$(./u2 --version 2>&1); then
    case "$ver" in
        *unstamped*) bad "--version says 'unstamped': the Makefile stopped passing the build stamp ($ver)" ;;
        *) ok "--version is stamped (not the unstamped fallback)" ;;
    esac
    printf '%s\n' "$ver" | grep -q 'build=terminal' \
        && ok "--version names the build target" \
        || bad "--version does not name the build target: $ver"
    printf '%s\n' "$ver" | grep -q 'sdl=none' \
        && ok "--version says this cc-only build has no SDL" \
        || bad "--version claims SDL in a build compiled without it: $ver"
    printf '%s\n' "$ver" | grep -q 'artifact=' \
        && ok "--version declares whether it is the shipped artifact" \
        || bad "--version omits the artifact field: $ver"
else
    bad "--version exited non-zero; a binary that cannot identify itself is the defect this flag exists to fix"
fi

# A key script is read only by the headless input backend. Silently dropping it is
# how a scripted run ends up waiting for a human, so it is refused out loud.
if timeout -s KILL 10 ./u2 --script "$SCRIPT" >/dev/null 2>"${WORK:-/var/tmp}/cp0-script.err"; then
    bad "--script was accepted without --headless, and would have been ignored"
else
    grep -q -- "--script needs --headless" "${WORK:-/var/tmp}/cp0-script.err" \
        && ok "--script without --headless refuses instead of ignoring the keys" \
        || bad "--script without --headless failed without the explanatory message"
fi

[ "$fail" = "0" ] && { echo "CP0 TEST: PASS"; exit 0; } || { echo "CP0 TEST: FAIL"; exit 1; }
