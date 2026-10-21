"""Programmatic checks: palette, tiling seams, silhouette distinctness.

Note on ordering: the file-level checks (section 1) must read the *committed*
tiles, not freshly generated ones. This script used to call build_all() first,
which rewrote every file in tiles/ before the checks opened them, so the checks
always passed against the generator and could never detect a defect in the
committed art. Grids are now built into memory only; nothing is written.
"""

import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import tiles as T  # noqa: E402

# Build grids in memory WITHOUT touching tiles/ on disk.
grids = {art: fn() for art, fn in T.TILES.items()}
for art, ch in T.LETTER_IDX.items():
    grids[art] = T.letter_tile(ch)
errs = T.validate(grids)

# --- 1. palette purity in emitted files -----------------------------------
ALLOWED = set(T.PAL.values())
svgdir = os.path.join(HERE, "..", "tiles")
for fn in sorted(os.listdir(svgdir)):
    text = open(os.path.join(svgdir, fn)).read()
    import re
    for hexval in re.findall(r"#[0-9A-Fa-f]{6}", text):
        if hexval.upper() not in ALLOWED:
            errs.append("%s: stray colour %s" % (fn, hexval))
    # Black is the backdrop, not ink. The engine clears the cell to black, so a
    # black rect and an absent rect are the same picture, and emitting black
    # makes tiles compose inconsistently. This is a structural test the proof
    # sheet cannot provide: on a black proof, black ink and transparency are
    # indistinguishable.
    if "#000000" in text.upper():
        errs.append("%s: emits #000000; black must come from the backdrop" % fn)
    if 'viewBox="0 0 16 16"' not in text:
        errs.append("%s: bad viewBox" % fn)
    if "crispEdges" not in text:
        errs.append("%s: missing crispEdges" % fn)
    if "width=" in text.split("viewBox")[0]:
        errs.append("%s: fixed width/height" % fn)

# --- 2. seamless tiling for ground ---------------------------------------
GROUND = [0x00, 0x01, 0x02, 0x03, 0x04, 0x09, 0x1C]
# For a repeating texture there is no hard rule; report edge-wrap similarity so
# we can see whether a tile has a conspicuous flat border.
for art in GROUND:
    g = grids[art]
    top, bot = g[0], g[15]
    left = "".join(r[0] for r in g)
    right = "".join(r[15] for r in g)
    # a seam shows up when the edge lines are empty (blank gutters) on both sides
    for label, a, b in (("horiz", top, bot), ("vert", left, right)):
        if a.count(".") == 16 and b.count(".") == 16:
            errs.append("%02X: blank %s gutters (seam)" % (art, label))

# --- 3. per-class distinctness -------------------------------------------
CLASSES = {
    "creature": [0x0C, 0x0D, 0x0E, 0x0F, 0x10, 0x11, 0x18, 0x19,
                 0x1A, 0x1B, 0x3C, 0x3D, 0x3E, 0x3F],
    "structure": [0x05, 0x06, 0x07, 0x08, 0x0A, 0x0B, 0x12, 0x13,
                  0x14, 0x15, 0x16, 0x30],
    "ground": GROUND,
    "blocks": [0x17, 0x1D, 0x1E, 0x1F, 0x3A, 0x3B],
}


def hamming(a, b):
    return sum(1 for ra, rb in zip(grids[a], grids[b])
               for ca, cb in zip(ra, rb) if ca != cb)


DUPES = []
for cls, members in CLASSES.items():
    for i, a in enumerate(members):
        for b in members[i + 1:]:
            d = hamming(a, b)
            if d == 0:
                DUPES.append("%s: %02X == %02X (identical)" % (cls, a, b))
            elif d <= 3:
                DUPES.append("%s: %02X ~ %02X (only %d px differ)"
                             % (cls, a, b, d))

# --- 4. non-empty check --------------------------------------------------
# 1D (solid black) is legitimately empty: the backdrop supplies its black, so
# an empty file is the correct representation, not a bug.
EMPTY_OK = {0x1D}
for art, g in grids.items():
    ink = sum(1 for r in g for c in r if c != "." and c != "K")
    if ink == 0 and art not in EMPTY_OK:
        errs.append("%02X: blank tile" % art)

print("=== ERRORS (%d) ===" % len(errs))
for e in errs:
    print("  " + e)
print("=== NEAR-DUPLICATES / IDENTICAL (%d) ===" % len(DUPES))
for d in DUPES:
    print("  " + d)

print("=== ink coverage per tile ===")
order = sorted(grids)
for art in order:
    ink = sum(1 for r in grids[art] for c in r if c != ".")
    print("  %02X %3d px" % (art, ink), end="")
    if order.index(art) % 8 == 7:
        print()
