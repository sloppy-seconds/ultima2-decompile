#!/usr/bin/env bash
# build_themes_selftest.sh — controls for tools/build_themes.py.
#
# AGENTS.md § 3: a gate has to be able to fail in the place that enforces it, and
# the control that makes it red gets written first. The gate here is
# `build_themes.py --verify`, and the failure it exists to catch is the
# half-recoloured theme: a tree that loads, renders, and is quietly wrong because
# one file from the source theme did not make it across. Every byte-level check
# passes on such a tree, which is the shape this project keeps getting bitten by.
#
# Cases 2-6 each break the tree in one of the ways that happens by accident, and
# the gate must go red. Case 1 is the control on the control: an untouched build
# must be green, or "red" means nothing.
#
# Run from the repo root:  bash tools/build_themes_selftest.sh
# A synthetic source tree is built under /var/tmp so the controls do not depend
# on the player's own media being present; the real sources are exercised by
# tools/check_all.sh, which runs the tool against them when they exist.

set -u

HERE="$(cd "$(dirname "$0")/.." && pwd)"
TOOL="$HERE/tools/build_themes.py"
WORK="${WORK:-/var/tmp/u2-build-themes-selftest}"
fail=0

ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fail=$((fail+1)); }

# expect_red <label> <command...> — the gate must exit non-zero.
expect_red() {
    local label="$1"; shift
    if "$@" >/dev/null 2>&1; then
        bad "$label — gate stayed green"
    else
        ok "$label"
    fi
}

# expect_green <label> <command...>
expect_green() {
    local label="$1"; shift
    if "$@" >/dev/null 2>&1; then
        ok "$label"
    else
        bad "$label — gate went red"
        "$@" 2>&1 | tail -3 | sed 's/^/          /'
    fi
}

rm -rf "$WORK"; mkdir -p "$WORK/src/EGATHEME.FOO" "$WORK/src2" "$WORK/out"

# A synthetic source with the same shape as the real one: a top-level atlas, one
# theme that carries extras (EGACOLOR), one theme that carries EGATILES alone,
# and a picture whose sibling spelling appears only in the second source.
# Content is a repeated printable byte — only size and distinctness matter here.
SRC="$WORK/src"; SRC2="$WORK/src2"; OUT="$WORK/out"
fill() {   # fill <path> <bytes> <char>
    mkdir -p "$(dirname "$1")"
    head -c "$2" /dev/zero | tr '\0' "$3" > "$1"
}
fill "$SRC/EGATILES"                 8320  Z
fill "$SRC/EGATHEME.FOO/EGATILES"    8320  Q
fill "$SRC/EGATHEME.FOO/EGACOLOR"      32  O
fill "$SRC/EGATHEME.BARE/EGATILES"   8320  B
fill "$SRC/PICDNG.EGA"              64000  D
fill "$SRC2/PICDNG-E"               64000  X     # same base, later source: shadowed
fill "$SRC2/PICTWN-E"               64000  T

echo "== build_themes.py controls =="

# 1. a clean build verifies green
expect_green "clean build verifies" \
    python3 "$TOOL" --source "$SRC" --source "$SRC2" --out "$OUT"

# 2. THE named control: EGACOLOR omitted from a theme that ships one.
mv "$OUT/EGATHEME.FOO/EGACOLOR" "$WORK/EGACOLOR.hidden"
expect_red "missing EGACOLOR is caught" \
    python3 "$TOOL" --source "$SRC" --source "$SRC2" --out "$OUT" --verify
mv "$WORK/EGACOLOR.hidden" "$OUT/EGATHEME.FOO/EGACOLOR"

# 3. a truncated atlas
head -c 4096 "$SRC/EGATILES" > "$OUT/EGATILES.short"
mv "$OUT/EGATILES" "$WORK/EGATILES.good"; mv "$OUT/EGATILES.short" "$OUT/EGATILES"
expect_red "truncated EGATILES is caught" \
    python3 "$TOOL" --source "$SRC" --source "$SRC2" --out "$OUT" --verify
mv "$WORK/EGATILES.good" "$OUT/EGATILES"

# 4. same size, different bytes (a re-encoded or edited atlas)
printf '\x00' | dd of="$OUT/EGATHEME.FOO/EGATILES" bs=1 seek=100 count=1 conv=notrunc 2>/dev/null
expect_red "edited EGATILES bytes are caught" \
    python3 "$TOOL" --source "$SRC" --source "$SRC2" --out "$OUT" --verify
python3 "$TOOL" --source "$SRC" --source "$SRC2" --out "$OUT" >/dev/null   # rebuild

# 5. a stray file nobody built (a hand-edited tree)
: > "$OUT/EGATHEME.FOO/EGASNEAK"
expect_red "stray file in the tree is caught" \
    python3 "$TOOL" --source "$SRC" --source "$SRC2" --out "$OUT" --verify
rm -f "$OUT/EGATHEME.FOO/EGASNEAK"

# 6. a stale manifest row (tree rebuilt from different sources, manifest not)
printf 'EGATILES\tatlas\tsomewhere/else\t8320\tdeadbeefdeadbeef\n' >> "$OUT/_BUILD.tsv"
expect_red "stale manifest row is caught" \
    python3 "$TOOL" --source "$SRC" --source "$SRC2" --out "$OUT" --verify
python3 "$TOOL" --source "$SRC" --source "$SRC2" --out "$OUT" >/dev/null

# 7. an empty theme directory is a problem, and a problem blocks the build
mkdir -p "$WORK/src3/EGATHEME.EMPTY"
expect_red "EGATHEME.* with no EGATILES refuses to build" \
    python3 "$TOOL" --source "$WORK/src3" --out "$WORK/out3"

# 8. dry-run writes nothing
rm -rf "$WORK/out4"
python3 "$TOOL" --source "$SRC" --out "$WORK/out4" --dry-run >/dev/null
if [ -e "$WORK/out4" ]; then bad "dry-run wrote to $WORK/out4"; else ok "dry-run writes nothing"; fi

# 9. refuses to write into the player's pristine media
expect_red "refuses --out under original/" \
    python3 "$TOOL" --source "$SRC" --out "$HERE/original/themes"
expect_red "refuses --out under references/" \
    python3 "$TOOL" --source "$SRC" --out "$HERE/references/u2upgrade/themes"

# 10. one file per picture base: the later source's spelling is shadowed, not
#     added alongside, because the engine would let the suffix order decide.
if [ -e "$OUT/PICDNG-E" ]; then
    bad "both spellings of PICDNG landed in the tree"
else
    ok "one file per picture base (PICDNG-E shadowed by PICDNG.EGA)"
fi
expect_green "tree still verifies after all controls" \
    python3 "$TOOL" --source "$SRC" --source "$SRC2" --out "$OUT" --verify

echo
if [ "$fail" -ne 0 ]; then
    echo "build_themes_selftest: $fail FAILED"
    exit 1
fi
echo "build_themes_selftest: all controls behaved"
exit 0
