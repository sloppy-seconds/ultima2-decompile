#!/usr/bin/env python3
"""Extract the letter runs from the shipped sector maps.

The A-Z art entries (art 0x20-0x39, map bytes 0x80-0xE4) are town signs and shop
fronts: impassable, but talkable-through (docs/passability-findings.md F13). In
the map files they occur as horizontally adjacent tiles, so a run of them spells
a name. This walks every row of every mapxNN and prints each run of two or more
letters with its origin, which recovers the shop and place names verbatim.

Art 0x30 (byte 0xC0) is deliberately excluded: it is not a letter, and it behaves
like a structure or event tile rather than a sign.

Read-only. Writes nothing; output goes to stdout.

Usage: python3 tools/map_signs.py > disasm/map-signs.txt
"""
import glob
import os

LETTER = {}
for a in range(0x20, 0x3A):
    if a == 0x30:
        continue                      # byte 0xC0 is not a letter
    LETTER[a << 2] = chr(ord('A') + (a - 0x20))

for path in sorted(glob.glob('original/mapx*')):
    d = open(path, 'rb').read()[:4096]
    runs = []
    for r in range(64):
        row = d[r * 64:(r + 1) * 64]
        i = 0
        while i < 64:
            if row[i] in LETTER:
                j, s = i, ''
                while j < 64 and row[j] in LETTER:
                    s += LETTER[row[j]]
                    j += 1
                if j - i >= 2:
                    runs.append((i, r, s))
                i = j
            else:
                i += 1
    letters = sum(1 for b in d if b in LETTER)
    if runs:
        print('%s  letters=%4d  runs>=2: %s' % (
            os.path.basename(path), letters,
            '  '.join('%s@%d,%d' % (s, x, y) for x, y, s in runs)))
    else:
        print('%s  letters=%4d  (no adjacent pairs)' % (os.path.basename(path), letters))
