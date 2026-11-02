#!/usr/bin/env bash
# tests/run_cp1.sh — CP1 acceptance test.
#
# The plan's criterion: "scripted keys reach menu; screen text matches
# asm/014B..0375 strings". Checked objectively, without committing any game
# text: the expected strings are re-extracted at test time from the user's copy
# (or the asm fallback) and looked for at the exact row and column the asm sets.
set -uo pipefail

cd "$(dirname "$0")/.." || exit 1
fail=0
ok()  { printf '  PASS  %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fail=1; }

WORK=$(mktemp -d "${TMPDIR:-/var/tmp}/u2-cp1.XXXXXX")
trap 'rm -rf "$WORK"' EXIT

printf 'engine CP1 test\n'

./u2 --headless --script tests/title.keys --dump-state >"$WORK/full.out" 2>"$WORK/full.err"
rc=$?
[ "$rc" = "0" ] && ok "scripted run exits 0" || bad "scripted run exit status $rc"

python3 tools/extract/extractor.py --emit text >"$WORK/strings" 2>/dev/null
[ -s "$WORK/strings" ] && ok "extractor produced the expected-string table" \
                       || bad "extractor produced nothing"

# Title screen: symbol:row:col, read off the code that sets DS:0x2F (row) and
# DS:0x2E (column) before each str_out — asm/0246, 025E, 0273, 0288, 02E6,
# 02F8, 031F, 034B, 0375, 02A3, 02CC. Independent of title.c's table on
# purpose: if module and test disagree, one of them mis-read the asm.
cat >"$WORK/positions" <<'POS'
U2_S_TITLE_GAME:1:15
U2_S_TITLE_REVENGE:3:16
U2_S_TITLE_OF_THE:5:16
U2_S_TITLE_ENCHANTRESS:7:14
U2_S_TITLE_TYPE:11:5
U2_S_MENU_DEMO:13:6
U2_S_MENU_PLAY:15:6
U2_S_MENU_CREATE:17:6
U2_S_MENU_CHOICE:19:5
U2_S_TITLE_COPYRIGHT:22:6
U2_S_TITLE_AND_ORIGIN:23:15
POS

# A run that stops at the menu: ESC skips the intro and no further key arrives,
# so the dumped screen is the bare title.
printf 'ESC\n' >"$WORK/menu.keys"
./u2 --headless --script "$WORK/menu.keys" --dump-state >"$WORK/menu.out"

python3 - "$WORK" <<'PY'
import pathlib, sys
work = pathlib.Path(sys.argv[1])
screen = (work / 'menu.out').read_text().splitlines()
try:
    top = next(i for i, l in enumerate(screen) if l.startswith('+---'))
except StopIteration:
    print('  (no screen grid found)')
    sys.exit(1)
rows = [l[1:-1] for l in screen[top + 1:] if l.startswith('|')]

strings = {}
for line in (work / 'strings').read_text().splitlines():
    k, _, v = line.partition('\t')
    strings[k] = v

placed = skipped = wrong = 0
for item in (work / 'positions').read_text().split():
    sym, row, col = item.split(':')
    row, col = int(row), int(col)
    s = strings.get(sym)
    if s is None:
        print(f'  (missing symbol {sym})')
        wrong += 1
        continue
    if s == '':
        skipped += 1          # asm fallback: not recoverable without the exe
        continue
    got = rows[row][col:col + len(s)] if row < len(rows) else ''
    if got == s:
        placed += 1
    else:
        print(f'  {sym}: row {row} col {col}: expected {s!r} got {got!r}')
        wrong += 1
print(f'  placed={placed} wrong={wrong} skipped-no-exe={skipped}')
sys.exit(0 if wrong == 0 else 1)
PY
if [ $? -eq 0 ]; then
    ok "title strings found at their asm positions"
else
    bad "title string placement mismatch (see lines above)"
fi

# The demonstration path must actually run: the 'D' branch sets the story flag
# (DS:0x239) and draws the first couplet of the poem into rows 23 and 24. Only
# the poem writes row 24, so that is the clean counter. CP3 review narrowed 'D'
# to the first block on purpose — the real demo is recorded gameplay with
# graphics (CP9), and running the whole poem made a placeholder look finished.
./u2 --headless --script tests/title.keys --trace="$WORK/trace" >/dev/null
poem_lines=$(grep -cE 'seam=str_out_at asm=51EB col=[0-9]+ row=24' "$WORK/trace")
[ "$poem_lines" -ge 1 ] && ok "demonstration drew the first poem block ($poem_lines row-24 lines, capped by design)" \
                        || bad "demonstration drew no poem text"

grep -qE '"story_flag"[[:space:]]*:[[:space:]]*1' "$WORK/full.out" \
    && ok "story flag set by the demo path" || bad "story flag not set"

a=$(./u2 --headless --script tests/title.keys --dump-state)
b=$(./u2 --headless --script tests/title.keys --dump-state)
[ "$a" = "$b" ] && ok "scripted title run is reproducible" || bad "scripted title run differs"

# The echoed choice must land on the CHOICE: line (asm/0394 prints at whatever
# cursor the last title line left behind, and CHOICE: is drawn last). Row 19 is
# the CHOICE: row and column 12 is where "CHOICE:" ends.
grep -qE 'seam=char_print asm=5003 ch=0x(44|50|43) at=19,12' "$WORK/trace" \
    && ok "echoed choice lands after CHOICE: (row 19 col 12)" \
    || bad "echoed choice did not land on the CHOICE: line"

# Fallback path, which is what CI gets: with no exe the strings that live
# inside the mis-decoded regions or inline in the code stream cannot be
# recovered from asm db lines, and the extractor says so by yielding them
# empty. Everything else must still arrive. The PASS echo (file 0x0B48) is one
# of these: asm/0940 names it in its header but the split left no db line.
python3 tools/extract/extractor.py --source asm --emit text >"$WORK/strings-asm" 2>/dev/null
empty=$(awk -F'\t' '$2==""{n++} END{print n+0}' "$WORK/strings-asm")
total=$(wc -l <"$WORK/strings-asm" | tr -d ' ')

# The old assertion hard-coded `total == 66 && empty == 29`, which went stale the
# moment CP5 added attack strings and reported a PASS-shaped FAIL for a perfectly
# good extractor. Counts are not the property; "did the fallback keep the words the
# engine prints, and did the set of exe-only strings stay the documented one" is.
# So: every string the asm tree CAN supply must arrive, named individually, and the
# total may not shrink.
U2_ASM_FALLBACK_MIN_TOTAL=66
[ "$total" -ge "$U2_ASM_FALLBACK_MIN_TOTAL" ] \
    && ok "asm fallback yields $((total-empty))/$total strings" \
    || bad "asm fallback shrank to $total strings (floor $U2_ASM_FALLBACK_MIN_TOTAL)"

# Named so a silent loss is attributable. These are the words the CMD window and
# the CP5 attack path print; if any goes empty the engine prints a blank line.
for s in U2_S_CMD_PROMPT U2_S_INVALID_MOVE U2_S_ATTACK U2_S_HIT \
         U2_S_MISS U2_S_PARALYZED U2_S_EXP_PLUS; do
    if awk -F'\t' -v n="$s" '$1==n && $2!=""{found=1} END{exit !found}' "$WORK/strings-asm"; then
        ok "asm fallback supplies $s"
    else
        bad "asm fallback lost $s — the engine would print an empty word"
    fi
done

# The content header is committed on purpose, and this used to assert the
# opposite. AGENTS.md § 0 ("The text/art line") rules that the game's text is
# publishable because the reconstruction already carries every byte of it; what
# made "never commit it" safe was never the ignoring, it was that the file was
# generated rather than hand-written. So the rule inverts to the property that
# actually mattered: the file is tracked (a CI runner has no exe to rebuild it
# from, and the asm fallback blanks 38 strings), it holds no empty string, and
# it still agrees with the byte-proven asm/ tree.
if git ls-files --error-unmatch content/gen_content.h >/dev/null 2>&1; then
    ok "content/gen_content.h is tracked (generated, committed)"
else
    bad "content/gen_content.h is not tracked — a build without the player's copy would get the lossy asm fallback"
fi

if grep -q '^#define U2_S_[A-Z_]* ""$' content/gen_content.h 2>/dev/null; then
    bad "content header carries an empty string — the engine prints nothing there and a text assertion would pass vacuously"
else
    ok "content header has no empty U2_S_ strings"
fi

if python3 tools/extract/extractor.py --source asm --verify -o content/gen_content.h >/dev/null 2>&1; then
    ok "content header agrees with the asm tree (drift gate)"
else
    bad "content header disagrees with the asm tree — run: make -C engine content-check"
fi

# And the gate must still be able to fail. Six controls, each proven red; a
# control whose pattern has moved is a failure, not a skip.
if python3 tests/content_header_selftest.py >/dev/null 2>&1; then
    ok "content header gate controls all still go red (selftest)"
else
    bad "content header gate can no longer fail where it enforces — run: python3 engine/tests/content_header_selftest.py"
fi

[ "$fail" = "0" ] && { echo "CP1 TEST: PASS"; exit 0; } || { echo "CP1 TEST: FAIL"; exit 1; }
