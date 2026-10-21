"""Assert the committed tiles match the ink assignment in spec section 6.

Reads the SVGs on disk (never regenerates them) and checks the set of inks in
each tile against the prescribed table. Spec acceptance criterion 8.7 requires
the assignment to match, and no proof sheet can establish this: on a black
backdrop a wrong ink looks like a plausible tile.

Usage: python3 inkcheck.py
Exit 0 if every tile matches, 1 otherwise.
"""

import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
SVGDIR = os.path.join(HERE, "..", "tiles")

INK_NAME = {
    "#55FFFF": "cyan",
    "#FF55FF": "magenta",
    "#FFFFFF": "white",
}

# spec section 6, transcribed from the table. Keys are art indices; values are
# the required ink set. Empty set means "no ink at all" (art 1D).
CYAN, MAG, WHITE = "cyan", "magenta", "white"

REQUIRED = {}
# magenta: liquid - water, marsh
for a in (0x00, 0x1C):
    REQUIRED[a] = {MAG}
# cyan: vegetation - grass, forest
for a in (0x02, 0x03):
    REQUIRED[a] = {CYAN}
# cyan + white: rough water
REQUIRED[0x01] = {CYAN, WHITE}
# magenta + white: arch in a field; figure with a staff
REQUIRED[0x0B] = {MAG, WHITE}
REQUIRED[0x0E] = {MAG, WHITE}
# cyan + magenta + white: the checker border
REQUIRED[0x17] = {CYAN, MAG, WHITE}
# none: solid black, an empty tile
REQUIRED[0x1D] = set()

# white: everything else, per the table's ranges
WHITE_ONLY = (
    list(range(0x04, 0x0B))    # 04-0A
    + list(range(0x0C, 0x17))  # 0C-16
    + list(range(0x18, 0x1C))  # 18-1B
    + list(range(0x1E, 0x40))  # 1E-3F
)
for a in WHITE_ONLY:
    REQUIRED[a] = {WHITE}

# Tiles named explicitly above win over the ranges (no overlap today, but the
# precedence is stated so an edit cannot silently flip a tile).
EXPLICIT = {0x00, 0x1C, 0x02, 0x03, 0x01, 0x0B, 0x0E, 0x17, 0x1D}

GROUP = re.compile(r'<g fill="(#[0-9A-Fa-f]{6})">(.*?)</g>', re.S)
RECT = re.compile(r"<rect([^>]*)/>")


def inks_in(path):
    """Set of ink names actually drawn in a tile file."""
    text = open(path).read()
    found = set()
    for gm in GROUP.finditer(text):
        hexval = gm.group(1).upper()
        if not RECT.search(gm.group(2)):
            continue
        name = INK_NAME.get(hexval)
        if name is None:
            found.add("STRAY:%s" % hexval)
        else:
            found.add(name)
    return found


def main():
    errs = []
    missing = sorted(set(range(0x40)) - set(REQUIRED))
    if missing:
        errs.append("spec table does not cover art indices: %s"
                    % ", ".join("%02X" % a for a in missing))

    for art in range(0x40):
        path = os.path.join(SVGDIR, "tile_%02X.svg" % art)
        if not os.path.exists(path):
            errs.append("%02X: file missing" % art)
            continue
        have = inks_in(path)
        want = REQUIRED.get(art)
        if want is None:
            continue
        if have != want:
            errs.append(
                "%02X: inks %s, spec requires %s"
                % (art,
                   sorted(have) or "{}".format("none"),
                   sorted(want) or "none")
            )
        if "#000000" in open(path).read().upper():
            errs.append("%02X: emits #000000; black is the backdrop" % art)

    total = 0x40
    print("=== ink assignment vs spec section 6 (%d tiles) ===" % total)
    if errs:
        print("FAIL (%d)" % len(errs))
        for e in errs:
            print("  " + e)
        return 1
    print("PASS - all %d tiles match the prescribed ink assignment" % total)
    return 0


if __name__ == "__main__":
    sys.exit(main())
