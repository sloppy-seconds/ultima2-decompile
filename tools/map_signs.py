#!/usr/bin/env python3
"""Extract the letter runs from the shipped sector maps.

The A-Z art entries (art 0x20-0x39, map bytes 0x80-0xE4) are town signs and shop
fronts: impassable, but talkable-through (docs/passability-findings.md F13). In
the map files they occur as horizontally adjacent tiles, so a run of them spells
a name. This walks every row of every mapxNN and prints each run of two or more
letters with its origin, which recovers the shop and place names verbatim.

Art 0x30 (byte 0xC0) is deliberately excluded: it is not a letter, and it behaves
like a structure or event tile rather than a sign.

Columns are scanned too, but a vertical run is only interesting if it is not just
two horizontal signs printed on neighbouring rows, so every vertical run is
classified: `artifact` when both of its cells already belong to horizontal runs of
their own, and `VERTICAL` when at least one cell does not. The distinction is what
makes the negative result in docs/place-names.md § 2b checkable rather than a
claim; `--selftest` plants a genuine downward sign and fails if the classifier
calls it an artifact.

Read-only. Writes nothing; output goes to stdout.

Usage: python3 tools/map_signs.py [--vertical] [--all] > disasm/map-signs.txt
       python3 tools/map_signs.py --selftest
"""
import glob
import os
import sys

LETTER = {}
for a in range(0x20, 0x3A):
    if a == 0x30:
        continue                      # byte 0xC0 is not a letter
    LETTER[a << 2] = chr(ord('A') + (a - 0x20))

# Byte 0x7C (art 1F) is the space of the map font: a single cell between words.
# mapx31 row 0 is the clean example - THINGS 7C ARE 7C NOT 7C AS 7C THEY 7C SEEM.
# Without treating it as a space every sentence fragments into single words, which
# is what an earlier revision of this tool did.
SPACE = 0x7C

# Byte 0x04 (art 01) is the near-blank tile town text is written on. It is ground,
# not a space, and the distinction matters: the mid-word holes in mapx41 are 0x04,
# so they are not spaces and must not be absorbed by the separator rule.
BLANK = 0x04

# Two signs in mapx41 have a single blank cell in the middle of a word: MINIS_RY at
# 53,15 and PROPAGA_DA at 52,19. The cells above, below and around are all 0x04, so
# this is not a missing glyph and not a two-row sign - T and N are both used
# correctly elsewhere in the same sector (TEST, DEFENCE). Left as-is rather than
# silently repaired: per the provenance note in AGENTS.md this pack appears to have
# community patches applied, and a one-cell hole in two adjacent signs is exactly
# the kind of artifact that would produce.

# Art 30 / byte 0xC0 stays excluded from LETTER: it is not a letter (see the no-Q
# note below).

# There is no Q glyph in use. Art 30, where Q would fall in the A-Z sequence, is a
# structural tile, and 0xC0 never appears between two letter tiles in any
# non-structural sector: every apparent case is in the A/0xC0 flood sectors, where
# the two are intermixed as built fabric rather than as text.

# A/Y flood: eight sectors use the letter tiles as plain building material, and in
# every one of them the letter population is *exclusively* A and Y - mapx15 1648 A /
# 97 Y, mapx24 1904/256, mapx25 1760/109, mapx34 2807/56, mapx35 1760/109,
# mapx44 2182/45, mapx45 1760/109, mapx85 1266/233. No sector that spells anything
# reaches even 16 % A+Y (mapx93 is the highest at 15.7 %), so "every letter tile is
# A or Y" separates the two populations exactly, with a wide margin. Dumping runs for
# those sectors produced 1556 of the 1731 lines of the first inventory and every one
# of them was `AAA` or `AYAYA`; they are summarised instead of listed unless --all.
FLOOD_MIN = 50


def is_structural(data):
    """True when every letter tile in the sector is A or Y (built fabric, not text)."""
    letters = [LETTER[b] for b in data if b in LETTER]
    return len(letters) >= FLOOD_MIN and all(c in 'AY' for c in letters)


def hruns(data):
    """Horizontal runs of >= 2 letters. Returns [(x, y, text, cells)]."""
    out = []
    for r in range(64):
        row = data[r * 64:(r + 1) * 64]
        i = 0
        while i < 64:
            if row[i] in LETTER:
                j, s, cells = i, '', []
                while j < 64 and (row[j] in LETTER or row[j] == SPACE):
                    if row[j] in LETTER:
                        s += LETTER[row[j]]
                        cells.append((j, r))
                    elif s:
                        s += ' '
                    j += 1
                s = s.rstrip(' ')
                if len(s.replace(' ', '')) >= 2:
                    out.append((i, r, s, cells))
                i = j
            else:
                i += 1
    return out


def vruns(data, horiz):
    """Vertical runs of >= 2 letters, each classified against the horizontal runs.

    Three verdicts:

    * `artifact`  - every cell already belongs to a horizontal run of its own, so
      this is two signs printed on neighbouring rows, not a sign reading downward.
    * `graphic-I` - the cells *not* owned by a horizontal run all hold the letter
      `I`. `I` (byte 0xA0) doubles as a small graphic mark the way A and Y double as
      generic solids: 94 of its 169 shipped occurrences (55.6 %) sit outside any
      word, four times the lone-rate of any other non-A/Y letter, and they cluster
      in dot patterns on town structures rather than in columns.
    * `VERTICAL`  - anything else, i.e. a genuine candidate for downward text.
    """
    owned = set()
    for _, _, _, cells in horiz:
        owned.update(cells)
    out = []
    for c in range(64):
        r = 0
        while r < 64:
            if data[r * 64 + c] in LETTER:
                j, s, cells = r, '', []
                while j < 64 and (data[j * 64 + c] in LETTER
                                  or data[j * 64 + c] == SPACE):
                    if data[j * 64 + c] in LETTER:
                        s += LETTER[data[j * 64 + c]]
                        cells.append((c, j))
                    elif s:
                        s += ' '
                    j += 1
                s = s.rstrip(' ')
                if len(s.replace(' ', '')) >= 2:
                    unowned = [LETTER[data[rr * 64 + c]]
                               for (_c, rr) in cells if (_c, rr) not in owned]
                    if not unowned:
                        kind = 'artifact'
                    elif all(ch == 'I' for ch in unowned):
                        kind = 'graphic-I'
                    else:
                        kind = 'VERTICAL'
                    out.append((c, r, s, kind))
                r = j
            else:
                r += 1
    return out


def sector(path):
    data = open(path, 'rb').read()[:4096]
    h = hruns(data)
    return data, h, vruns(data, h)


def report(path, show_vertical=True, show_all=False):
    data, h, v = sector(path)
    letters = sum(1 for b in data if b in LETTER)
    name = os.path.basename(path)
    if not show_all and is_structural(data):
        print('%s  letters=%4d  (structural: every letter tile is A or Y)' % (name, letters))
        return
    if h:
        print('%s  letters=%4d  runs>=2: %s' % (
            name, letters,
            '  '.join('%s@%d,%d' % (s, x, y) for x, y, s, _ in h)))
    else:
        print('%s  letters=%4d  (no adjacent pairs)' % (name, letters))
    if not show_vertical or not h:
        return
    real = [t for t in v if t[3] == 'VERTICAL']
    art = [t for t in v if t[3] == 'artifact']
    gra = [t for t in v if t[3] == 'graphic-I']
    if real:
        print('%s  vertical: %s' % (
            ' ' * len(name),
            '  '.join('%s@%d,%d' % (s, x, y) for x, y, s, _ in real)))
    else:
        parts = []
        if art:
            parts.append('%d column run%s read as two signs on adjacent rows'
                         % (len(art), '' if len(art) == 1 else 's'))
        if gra:
            parts.append('%d %s the lone-`I` graphic'
                         % (len(gra), 'is' if len(gra) == 1 else 'are'))
        print('%s  vertical: none (%s)' % (
            ' ' * len(name), '; '.join(parts) if parts else 'no column runs'))


def selftest():
    """Control: a genuine downward sign must be reported, not waved away.

    Builds a 64x64 sector holding the horizontal sign `SHOP` at (10,20), the
    downward sign `BAR` at (40,30..32) with no horizontal partner, a stacked pair
    `REST`/`REST` at rows 40/41, and a lone-`I` column at (55,10..11). Asserts the
    classifier keeps BAR as VERTICAL, waves away the stacked pair as an artifact and
    the I column as the graphic, and does not lose SHOP.
    """
    def byte(ch):
        return (0x20 + ord(ch) - ord('A')) << 2

    grid = bytearray(4096)
    for i, ch in enumerate('SHOP'):
        grid[20 * 64 + 10 + i] = byte(ch)
    for i, ch in enumerate('BAR'):
        grid[(30 + i) * 64 + 40] = byte(ch)
    # two horizontal signs on adjacent rows: must come back as an artifact
    for i, ch in enumerate('REST'):
        grid[40 * 64 + 5 + i] = byte(ch)
        grid[41 * 64 + 5 + i] = byte(ch)
    # a lone-`I` column: the graphic, not text
    for i in range(2):
        grid[(10 + i) * 64 + 55] = byte('I')
    data = bytes(grid)
    h = hruns(data)
    v = vruns(data, h)
    texts = {(s, k) for _, _, s, k in v}
    bad = 0
    if ('BAR', 'VERTICAL') not in texts:
        print('SELFTEST FAIL: planted downward sign BAR not reported as VERTICAL '
              '(got %s)' % sorted(texts))
        bad += 1
    if not all(k == 'artifact' for s, k in texts if s in ('RR', 'EE', 'SS', 'TT')) \
            or not any(s == 'RR' for s, k in texts):
        print('SELFTEST FAIL: stacked REST/REST not classified as artifact '
              '(got %s)' % sorted(texts))
        bad += 1
    if ('II', 'graphic-I') not in texts:
        print('SELFTEST FAIL: lone-I column not classified as graphic-I '
              '(got %s)' % sorted(texts))
        bad += 1
    if not any(s == 'SHOP' for _, _, s, _ in h):
        print('SELFTEST FAIL: horizontal SHOP not found')
        bad += 1
    # The A/Y structural filter must not swallow a sector that also spells something.
    flooded = bytearray(4096)
    for i in range(60):
        flooded[i] = byte('A') if i % 2 else byte('Y')
    for i, ch in enumerate('BAR'):
        flooded[30 * 64 + 10 + i] = byte(ch)
    if is_structural(bytes(flooded)):
        print('SELFTEST FAIL: a flooded sector holding a real sign was filtered '
              'out as structural')
        bad += 1
    pure_flood = bytearray(4096)
    for i in range(60):
        pure_flood[i] = byte('A') if i % 2 else byte('Y')
    if not is_structural(bytes(pure_flood)):
        print('SELFTEST FAIL: a pure A/Y sector was not recognised as structural')
        bad += 1
    if bad:
        return 1
    print('SELFTEST PASS: downward sign detected, stacked horizontal pair '
          'classified as artifact, lone-I column as the graphic, and the A/Y '
          'filter keeps any sector that also spells a sign')
    return 0


def main(argv):
    if '--selftest' in argv:
        return selftest()
    show_all = '--all' in argv
    show_vertical = '--no-vertical' not in argv
    args = [a for a in argv[1:] if not a.startswith('--')]
    paths = args or sorted(glob.glob('original/mapx*'))
    for p in paths:
        report(p, show_vertical=show_vertical, show_all=show_all)
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv))
