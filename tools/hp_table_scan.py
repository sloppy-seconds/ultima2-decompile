#!/usr/bin/env python3
"""hp_table_scan.py — is monster HP stored per creature, or computed?

Why: the third-party bestiary (docs/bestiary.md) gives every creature an HP figure,
and the overworld table gives a single number while the Townsfolk and Dungeon tables
give a *range*. If HP were a stored per-type constant the ranges would be impossible,
and if it were a stored per-type pair we should be able to find the table in the
binary and promote the whole stat column from third-party to measured.

Result on the current tree (2026-10-22): **no stored table exists**, across 13
encoding x indexing combinations — raw byte, 16-bit LE and the hundreds-first BCD
pair the player's own HP uses, indexed by art and by the type/sprite values that fold
to an art under >>2. `original/monsters` (64 records x 34 B) was also tested and is
coordinate pairs, not stats. What the scan *did* find is that the seven dungeon HP
ranges are two exact arithmetic progressions, min = 17 + 32k and max = 153 + 32*(k//2)
in dungeon-table order, 7/7 on both. So dungeon HP is computed from creature index
and depth, and finding the formula is a disassembly task, not a capture.

Read the negative as the useful answer: a tool that reported a hit from a loose
threshold would have sent the project hunting a table that does not exist. The
match bar here is deliberately `all but one` of the known entries, and nothing
reached it.

Usage:
    python3 tools/hp_table_scan.py [--exe original/ultimaii.exe]
"""
import argparse
import os
import sys

PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# art index -> third-party HP. Single values come from the overworld table; the
# ranges come from the Townsfolk and Dungeon tables (see docs/bestiary.md § 8 for
# why those two tables' columns are a range and not HP+DMG).
SINGLE = {0x0B: 64, 0x0C: 16, 0x0D: 64, 0x0E: 192, 0x0F: 255,
          0x12: 160, 0x3C: 128, 0x3E: 224, 0x3F: 32}
RANGES = {0x18: (255, 255), 0x19: (1, 255), 0x1A: (5, 50), 0x3D: (10, 60)}
DUNGEON = {0x0C: (17, 153), 0x0D: (177, 217), 0x0F: (209, 249)}

# Dungeon-table order, as the codex lists it. The progression is in this order,
# which is itself a claim: if the game's own index order differs, the fit is luck.
DUNGEON_SEQ = [('Orc', 17, 153), ('Ghost', 49, 153), ('Carrion creeper', 81, 185),
               ('Viper', 113, 185), ('Gremlin', 145, 217), ('Daemon', 177, 217),
               ('Balron', 209, 249)]


def bcd_pair(v):
    """Player HP encoding (DS:51/52): hundreds byte first, each a packed BCD pair."""
    if v > 9999:
        return None
    hi, lo = divmod(v, 100)
    return bytes([(hi // 10) << 4 | hi % 10, (lo // 10) << 4 | lo % 10])


def scan(data, name, table, idx_fn, enc, min_hits=None):
    items = [(idx_fn(a), enc(v)) for a, v in table.items()]
    items = [(i, e) for i, e in items if e is not None]
    if not items:
        print('%-46s 0 entries — nothing to test' % name)
        return []
    span = max(i + len(e) for i, e in items)
    need = min_hits or max(3, len(items) - 1)
    hits = []
    for o in range(0, len(data) - span):
        good = sum(1 for i, e in items if data[o + i:o + i + len(e)] == e)
        if good >= need:
            hits.append((good, len(items), hex(o)))
    print('%-46s %2d entries, need %d -> %s'
          % (name, len(items), need, hits if hits else 'no hit'))
    return hits


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument('--exe', default=os.path.join(PROJECT_ROOT, 'original', 'ultimaii.exe'))
    args = ap.parse_args()
    if not os.path.exists(args.exe):
        sys.exit('%s missing' % args.exe)
    data = open(args.exe, 'rb').read()
    print('exe %d bytes\n' % len(data))

    idx = (('index=art', lambda a: a),
           ('index=art*4', lambda a: a * 4),
           ('index=art*4+3', lambda a: a * 4 + 3))
    encs = (('raw byte', lambda v: bytes([v & 0xFF])),
            ('le16', lambda v: bytes([v & 0xFF, (v >> 8) & 0xFF])),
            ('bcd pair', bcd_pair))

    print('== stored-table search, overworld single HP values ==')
    found = []
    for iname, ifn in idx:
        for ename, efn in encs:
            if ename == 'bcd pair' and iname.endswith('+3'):
                continue
            found += scan(data, '%s, %s' % (ename, iname), SINGLE, ifn, efn)

    print('\n== range endpoints (min at i, max at i+1) ==')
    for iname, ifn in idx[:2]:
        found += scan(data, 'range bytes, %s' % iname, RANGES, ifn,
                      lambda v: bytes([v[0] & 0xFF]))
        found += scan(data, 'range le16, %s' % iname, RANGES, ifn,
                      lambda v: bytes([v[0] & 0xFF, v[1] & 0xFF]))

    print('\n== dungeon HP for the three arts the join also names ==')
    for which in (0, 1):
        found += scan(data, 'dungeon %s byte, index=art' % ('min' if which == 0 else 'max'),
                      {a: v[which] for a, v in DUNGEON.items()}, lambda a: a,
                      lambda v: bytes([v & 0xFF]), min_hits=3)

    print('\n== dungeon HP structure ==')
    ok_lo = ok_hi = 0
    for k, (nm, lo, hi) in enumerate(DUNGEON_SEQ):
        pred_lo, pred_hi = 17 + 32 * k, 153 + 32 * (k // 2)
        ok_lo += lo == pred_lo
        ok_hi += hi == pred_hi
        print('  k=%d %-16s min %3d vs 17+32k=%3d %-3s  max %3d vs 153+32*(k//2)=%3d %-3s'
              % (k, nm, lo, pred_lo, 'OK' if lo == pred_lo else 'NO',
                 hi, pred_hi, 'OK' if hi == pred_hi else 'NO'))
    print('  fit: %d/%d mins, %d/%d maxes' % (ok_lo, len(DUNGEON_SEQ), ok_hi, len(DUNGEON_SEQ)))

    print('\n== overworld HP structure ==')
    for a, v in sorted(SINGLE.items()):
        print('  art %02X  hp %3d  = 32*%-5s %s' % (a, v, v / 32, '(0xFF ceiling)' if v == 255 else ''))

    print('\nverdict: %s' % ('FOUND a stored table — investigate' if found
                             else 'no stored HP table; HP is computed'))
    print('next: find the computation in the spawn/combat code, not in a capture.')


if __name__ == '__main__':
    main()
