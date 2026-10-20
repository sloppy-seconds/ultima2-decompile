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

# Fallback path, which is what CI gets: with no exe the two strings that live
# inside the mis-decoded regions cannot be recovered from asm db lines, and the
# extractor says so by yielding them empty. Everything else must still arrive.
python3 tools/extract/extractor.py --source asm --emit text >"$WORK/strings-asm" 2>/dev/null
empty=$(awk -F'\t' '$2==""{n++} END{print n+0}' "$WORK/strings-asm")
total=$(wc -l <"$WORK/strings-asm" | tr -d ' ')
[ "$total" = "51" ] && [ "$empty" = "20" ] \
    && ok "asm fallback yields $((total-empty))/$total strings (20 are exe-only by design)" \
    || bad "asm fallback yielded $((total-empty))/$total with $empty empty"

# No game text may be committed: the generated header must stay ignored.
git check-ignore -q build/gen_content.h \
    && ok "generated content header is gitignored" \
    || bad "build/gen_content.h is NOT ignored"

[ "$fail" = "0" ] && { echo "CP1 TEST: PASS"; exit 0; } || { echo "CP1 TEST: FAIL"; exit 1; }
