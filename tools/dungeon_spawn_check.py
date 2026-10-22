#!/usr/bin/env python3
"""A4: prove the dungeon spawn formula against every dungeon dump on disk.

Reads the monster record out of `captures/spice86/*/spice86dumpMemoryDump.bin`
and checks it against what `asm/147F_dungeon_monster_spawn.asm` computes.

The routine, read instruction by instruction (runtime addresses, file = +0x200):

  L_0016d1  mov %di,%ax ; clc ; rcr $1,%al ; mov %al,0x1b7(%di)
            -> [slot+0x1B7] = slot >> 1
  L_0016df  call RNG ; and $0x7,%al ; cmp $0x7 ; je retry     -> v = rand&7, v != 7
  L_0016f0  add %al,%al ; cmp 0x1b7(%di),%al ; je ok ; jb ok  -> accept iff 2v <= kind
  L_0016fd  clc ; rcr $1,%al ; adc $0x1,%al ; mov %al,0x197  -> type = v + 1
  L_001706  add %al,%al ; adc 0x1b7(%di),%al ; add x3 ; or $0x10 ; mov %al,0x177
            -> HP = ((2*type + kind) * 8) | 0x10

A dungeon sector is detected by the record shape, not by the directory name:
`docs/monster-spawn.md` records that `airport32` is a dungeon with a stale name.

Read-only. Exits non-zero if a dungeon dump fails the formula, so it is usable
as a check rather than only as a report.

Usage: python3 tools/dungeon_spawn_check.py [--verbose]
"""
import os
import pathlib
import sys

DS_SEG = 0x08BE
DS_BASE = DS_SEG * 16
SLOTS = 32
OFF_X, OFF_Y, OFF_HP, OFF_TYPE, OFF_KIND = 0x137, 0x157, 0x177, 0x197, 0x1B7

# The overworld type range, from docs/monster-spawn.md: 0x2C..0xFC with 0x00 and
# 0x40 (the empty sentinel) excluded. A dungeon record holds small indices instead.
DUNGEON_TYPES = set(range(0x01, 0x08))


def hp_formula(type_, kind):
    """HP as asm/147F computes it. `*8` is the three `add %al,%al` after the adc."""
    return (((2 * type_ + kind) * 8) | 0x10) & 0xFF


def read_record(path):
    b = path.read_bytes()
    if len(b) < DS_BASE + OFF_KIND + SLOTS:
        return None
    g = lambda off: [b[DS_BASE + off + i] for i in range(SLOTS)]
    return {'x': g(OFF_X), 'y': g(OFF_Y), 'hp': g(OFF_HP),
            'type': g(OFF_TYPE), 'kind': g(OFF_KIND)}


def is_dungeon(rec):
    """Dungeon by encoding, not by name: every active slot holds a small index
    and every slot's kind equals slot>>1. Both are required -- the overworld
    filter `type not in (0, 0x40)` would wave these through as garbage."""
    act = [i for i in range(SLOTS) if rec['type'][i]]
    if not act:
        return False
    if not all(rec['type'][i] in DUNGEON_TYPES for i in act):
        return False
    return all(rec['kind'][i] == (i >> 1) for i in act)


def main(argv):
    verbose = '--verbose' in argv
    root = pathlib.Path('captures/spice86')
    if not root.is_dir():
        print('no captures/spice86 directory', file=sys.stderr)
        return 2
    total = fails = 0
    seen = []
    for d in sorted(root.iterdir()):
        p = d / 'spice86dumpMemoryDump.bin'
        if not p.is_file():
            continue
        rec = read_record(p)
        if rec is None or not is_dungeon(rec):
            continue
        seen.append(d.name)
        for i in range(SLOTS):
            t, k, h = rec['type'][i], rec['kind'][i], rec['hp'][i]
            if not t:
                continue
            total += 1
            want = hp_formula(t, k)
            guard = 2 * (t - 1) <= k          # accept iff 2v <= kind, v = type-1
            if want != h or not guard:
                fails += 1
                print('FAIL %s slot %d: type 0x%02X kind 0x%02X hp %d, formula %d, '
                      'guard %s' % (d.name, i, t, k, h, want, 'ok' if guard else 'BROKEN'))
            elif verbose:
                print('  ok %s slot %2d  x=%2d y=%2d  type 0x%02X kind 0x%02X  hp %d'
                      % (d.name, i, rec['x'][i], rec['y'][i], t, k, h))
    print('%d dungeon capture(s): %s' % (len(seen), ', '.join(seen) or 'none'))
    print('%d/%d monster slots satisfy HP = ((2*type + slot>>1)*8) | 0x10 and the '
          '2*(type-1) <= slot>>1 guard' % (total - fails, total))
    if not total:
        print('nothing to check -- no dungeon-shaped record found')
        return 1
    if fails:
        print('FORMULA FAILS on %d slot(s)' % fails)
        return 1
    print('DUNGEON SPAWN FORMULA: PASS')
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv))
