#!/usr/bin/env bash
# tests/run_cp2.sh — CP2 acceptance test: the CLI contract and its evidence.
#
# The plan asked for an MCP play-API; the owner redirected to "teach the agent
# the CLI, build the MCP later if needed" (docs/phase4-state.md gate log). The
# acceptance substance is unchanged: an agent can drive the game through a
# documented interface only, and produces a playthrough transcript that can be
# re-verified.
set -uo pipefail

cd "$(dirname "$0")/.." || exit 1
fail=0
ok()  { printf '  PASS  %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fail=1; }

WORK=$(mktemp -d "${TMPDIR:-/var/tmp}/u2-cp2.XXXXXX")
trap 'rm -rf "$WORK"' EXIT

printf 'engine CP2 test\n'

# --- the digest primitive the evidence rests on --------------------------
cc -std=c11 -Wall -Wextra -Werror -Isrc -o "$WORK/sha256_check" \
   tests/sha256_check.c src/core/sha256.c 2>"$WORK/cc.err"
if [ $? -ne 0 ]; then
    bad "sha256 test harness did not build: $(head -2 "$WORK/cc.err")"
else
    "$WORK/sha256_check" > "$WORK/c.txt"
    python3 - "$WORK/c.txt" <<'PY' > "$WORK/py.txt"
import hashlib, sys
data = bytes(ord('a') + (i % 26) for i in range(1024))
for line in open(sys.argv[1]):
    n = int(line.split()[0])
    print(f"{n} {hashlib.sha256(data[:n]).hexdigest()}")
PY
    cmp -s "$WORK/c.txt" "$WORK/py.txt" \
        && ok "in-tree sha256 matches hashlib at every block/padding boundary" \
        || bad "in-tree sha256 disagrees with hashlib"
fi

# --- the report: emitted, parseable, and free of game content ------------
./u2 --headless --script tests/play_to/menu_all_choices.keys --seed 0 \
     --replay-report "$WORK/run.json" >/dev/null
[ -s "$WORK/run.json" ] && ok "replay report written" || bad "no replay report"

python3 tools/extract/extractor.py --emit text > "$WORK/strings" 2>/dev/null
python3 - "$WORK/run.json" "$WORK/strings" <<'PY'
import json, pathlib, sys
rep = json.load(open(sys.argv[1]))
strings = [l.split('\t', 1)[1] for l in
           open(sys.argv[2]).read().splitlines() if '\t' in l]
text = json.dumps(rep)
leaks = [s for s in strings if len(s) > 3 and s in text]
assert leaks == [], f"game text in report: {leaks[:3]}"
assert rep["report"] == "u2-playthrough" and rep["version"] == 1
assert rep["keys"], "no keys recorded"
assert rep["steps"], "no steps recorded"
assert all(set(s) >= {"at_key", "screen", "state", "rolls"} for s in rep["steps"])
assert len(rep["final_state"]) > 0
print(f"steps={len(rep['steps'])} keys={len(rep['keys'])}")
PY
[ $? -eq 0 ] && ok "report parses and carries no game text" \
             || bad "report is malformed or leaks game text"

# --- determinism: the same inputs give the same evidence -----------------
./u2 --headless --script tests/play_to/menu_all_choices.keys --seed 0 \
     --replay-report "$WORK/run2.json" >/dev/null
cmp -s "$WORK/run.json" "$WORK/run2.json" \
    && ok "two runs produce identical reports" \
    || bad "reports differ between identical runs"

# --- the check has teeth: a different seed must diverge ------------------
./u2 --headless --script tests/play_to/menu_all_choices.keys --seed 37 \
     --replay-report "$WORK/seed37.json" >/dev/null
if cmp -s "$WORK/run.json" "$WORK/seed37.json"; then
    bad "changing --seed did not change the report (digests are not sensitive)"
else
    ok "a different seed produces a different report"
fi

# --- verification tool: proves a recorded run still reproduces -----------
python3 tools/playlog.py verify "$WORK/run.json" > "$WORK/verify.out" 2>&1
grep -q "REPLAY: REPRODUCES" "$WORK/verify.out" \
    && ok "playlog verify: recorded playthrough reproduces" \
    || bad "playlog verify failed: $(tail -3 "$WORK/verify.out")"

# and it must notice tampering
python3 - "$WORK/run.json" "$WORK/tampered.json" <<'PY'
import json, sys
rep = json.load(open(sys.argv[1]))
if rep["steps"]:
    rep["steps"][0]["screen"] = "0" * 64
json.dump(rep, open(sys.argv[2], "w"))
PY
python3 tools/playlog.py verify "$WORK/tampered.json" > "$WORK/tam.out" 2>&1
grep -q "REPLAY: DIVERGES" "$WORK/tam.out" \
    && ok "playlog verify detects a tampered transcript" \
    || bad "playlog verify accepted a tampered transcript"

# --- the documented interface is actually usable -------------------------
grep -q -- "--replay-report" docs/playing.md && grep -q "REPRODUCES" docs/playing.md \
    && ok "docs/playing.md documents the report and its verification" \
    || bad "docs/playing.md missing the report contract"
for f in title_menu demo_once menu_all_choices; do
    [ -f "tests/play_to/$f.keys" ] || bad "missing play_to script: $f"
done
n=$(./u2 --headless --script tests/play_to/demo_once.keys --dump-each | grep -c '^+---')
[ "$n" -ge 6 ] && ok "demo_once replays $((n/2)) frames through the documented CLI" \
               || bad "demo_once produced only $((n/2)) frames"

# --- the committed evidence still reproduces -----------------------------
if [ -f evidence/cp2-playthrough.json ]; then
    # The evidence is content-coupled: it was recorded against a specific string
    # source, and some strings are exe-only run locators that come out empty in
    # the asm-fallback build CI uses. A fallback build therefore paints fewer
    # frames and cannot reproduce an exe-recorded transcript — that is a
    # difference in what the binary contains, not a regression. Skip with a named
    # reason, exactly as CP1 skips exe-only strings, rather than fail spuriously.
    recorded=$(python3 -c "import json;print(json.load(open('evidence/cp2-playthrough.json')).get('content_source',''))" 2>/dev/null)
    current=$(./u2 --headless --script tests/play_to/title_menu.keys --dump-state 2>/dev/null \
              | tail -1 \
              | python3 -c "import json,sys;print(json.load(sys.stdin).get('content',''))" 2>/dev/null)
    if [ -n "$recorded" ] && [ -n "$current" ] && [ "$recorded" != "$current" ]; then
        printf '  SKIP  committed evidence reproduce-check (recorded against "%s", this build is "%s")\n' "$recorded" "$current"
    else
    python3 tools/playlog.py verify evidence/cp2-playthrough.json >"$WORK/ev.out" 2>&1
    grep -q "REPLAY: REPRODUCES" "$WORK/ev.out" \
        && ok "committed evidence/cp2-playthrough.json still reproduces" \
        || bad "committed evidence no longer reproduces: $(tail -3 "$WORK/ev.out")"
    fi
    python3 - evidence/cp2-playthrough.json "$WORK/strings" <<'PY'
import json, sys
rep = json.load(open("evidence/cp2-playthrough.json"))
strings = [l.split('\t', 1)[1] for l in open(sys.argv[2]) if '\t' in l]
text = json.dumps(rep)
leaks = [s for s in strings if len(s) > 3 and s in text]
assert not leaks, leaks[:3]
assert rep["keys"], "no keys"
assert len(rep["steps"]) >= 10, "too few steps recorded"
PY
    [ $? -eq 0 ] && ok "committed evidence is well-formed and carries no game text" \
                 || bad "committed evidence is malformed or leaks game text"
else
    bad "engine/evidence/cp2-playthrough.json is missing"
fi

# --- nothing generated may be committed ----------------------------------
git check-ignore -q build/gen_content.h \
    && ok "generated content header is gitignored" \
    || bad "build/gen_content.h is NOT ignored"

[ "$fail" = "0" ] && { echo "CP2 TEST: PASS"; exit 0; } || { echo "CP2 TEST: FAIL"; exit 1; }
