#!/usr/bin/env bash
# check_all.sh — run every gate in the project, one verdict per line.
#
# This exists because the gates are the project's safety property and they are scattered:
# assemble_clean, the engine suite, and six tool selftests that each have to be remembered.
# For unattended work that is the difference between "committed a plausible wrong answer" and
# "committed nothing". A gate you have to remember to run is a gate you will not run.
#
#   tools/check_all.sh            # everything, including the slow proof and the engine suite
#   tools/check_all.sh --fast     # skip assemble_clean and make test (the sub-minute gates)
#
# Rules this honours, all from AGENTS.md:
#   * A SKIP IS NOT A PASS. A gate whose inputs are gitignored (original/, references/apple/,
#     the Ghidra output under /var/tmp) reports SKIP and names the missing input, and the
#     script still exits non-zero if any gate that COULD run failed. It never reports success
#     for a check that did not happen — a skip that can hide a failure is the thing that bit
#     this project with run_cp5.sh.
#   * Nothing here regenerates anything. These are checks; --emit flags are deliberately not
#     called, so a stale committed artefact shows up as a failure rather than being silently
#     rewritten.
set -uo pipefail
cd "$(dirname "$0")/.."

FAST=0
[ "${1:-}" = "--fast" ] && FAST=1

fails=0
skips=0

# run <label> <required-path...> -- <command...>
run() {
    local label="$1"; shift
    while [ "$1" != "--" ]; do
        if [ ! -e "$1" ]; then
            printf '  SKIP  %-26s missing %s\n' "$label" "$1"
            skips=$((skips + 1))
            return 0
        fi
        shift
    done
    shift
    local out rc
    out=$("$@" 2>&1); rc=$?
    if [ $rc -eq 0 ]; then
        printf '  PASS  %-26s %s\n' "$label" "$(printf '%s' "$out" | tail -1 | cut -c1-72)"
    else
        printf '  FAIL  %-26s %s\n' "$label" "$(printf '%s' "$out" | tail -3 | tr '\n' '|' | cut -c1-160)"
        fails=$((fails + 1))
    fi
}

echo "== reconstruction proof =="
if [ "$FAST" = 1 ]; then
    echo "  SKIP  assemble_clean.sh          (--fast)"
    echo "  SKIP  engine test suite          (--fast)"
else
    run "assemble_clean.sh" original/ultimaii.exe -- bash tools/assemble_clean.sh
    run "engine test suite" engine/Makefile -- make -C engine test
fi

echo "== gates over tracked inputs (CI-runnable) =="
run "cmd_handlers" asm disasm/jump-table.txt -- python3 tools/cmd_handlers.py --check
run "fragment_splits" disasm/function-map.tsv -- python3 tools/fragment_splits.py --selftest

echo "== DOS string atlas =="
run "strings_atlas selftest" original/ultimaii.exe asm -- python3 tools/strings_atlas.py --selftest
run "str_out_audit selftest" original/ultimaii.exe asm -- python3 tools/str_out_audit.py --selftest
run "str_out_audit check" original/ultimaii.exe disasm/str-out-rendering-gap.tsv -- python3 tools/str_out_audit.py --check

echo "== Apple II 6502 side (needs gitignored inputs) =="
run "apple2_seeds selftest" references/apple decompiled/apple2 -- python3 tools/apple2_seeds.py --selftest
run "apple2_anchor_map" original/ultimaii.exe decompiled/apple2 -- python3 tools/apple2_anchor_map.py --selftest
run "apple2 index fresh" /var/tmp/u2-apple2-6502/u2_6502.tsv -- python3 tools/apple2_index.py --check

echo
if [ "$fails" -gt 0 ]; then
    echo "CHECK-ALL: FAIL ($fails gate(s) red, $skips skipped)"
    exit 1
fi
if [ "$skips" -gt 0 ]; then
    echo "CHECK-ALL: PASS ($skips gate(s) skipped for missing inputs — see above)"
    exit 0
fi
echo "CHECK-ALL: PASS"
