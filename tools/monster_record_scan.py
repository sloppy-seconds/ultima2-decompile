#!/usr/bin/env python3
"""monster_record_scan.py — read the monster record out of every saved capture.

Why: AGENTS.md says to list the existing corpus before harvesting runtime data, and
this session violated it. A fresh headless capture appeared to refute the spawn-arm
HP values (everything read 255); the answer was already in `captures/spice86/`, in
sixty-plus dumps nobody had read this way.

The monster record is three parallel byte arrays, stride 1, 32 slots, in the data
segment (docs/spice86-live-findings.md):

    x    = DS:0x137 + i
    hp   = DS:0x177 + i     # proven HP by asm/2E3D_combat_attack_flow
    type = DS:0x197 + i     # 0x40 = empty sentinel
    kind = DS:0x1B7 + i     # small kind index, NOT a sprite

Finding, for the record: the arm immediate is the BASE HP of an ordinary wandering
spawn. Area can raise it (castle-03-live: Thief base 32 seen at 100/150/200/250,
Devil base 192 at 255) and damage lowers it (Fighter 100 of 128, Devil 187 of 192).
The sector-0 compound saturates every slot to 255. So one 255-everywhere reading
proves nothing about the arms — check the area before concluding.

Usage:
    python3 tools/monster_record_scan.py                 # summary per capture
    python3 tools/monster_record_scan.py --detail castle-03-live
"""
import argparse
import collections
import os
import pathlib
import sys

PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DS_SEG = 0x08BE                      # proven in docs/spice86-capture.md
OFF_X, OFF_HP, OFF_TYPE, OFF_KIND = 0x137, 0x177, 0x197, 0x1B7
EMPTY = 0x40
SLOTS = 32

# type -> base HP stored by the spawn arms (tools/monster_hp_dispatch.py)
ARMS = {0x2C: 64, 0x30: 16, 0x34: 64, 0x38: 192, 0x3C: 255,
        0x48: 160, 0xF0: 128, 0xF8: 224, 0xFC: 32}
# art -> third-party name, for readability only (docs/bestiary.md)
NAMES = {0x2C >> 2: 'Sea serpent', 0x30 >> 2: 'Orc', 0x34 >> 2: 'Daemon',
         0x38 >> 2: 'Devil', 0x3C >> 2: 'Balron', 0x48 >> 2: 'Frigate',
         0x60 >> 2: 'Guard', 0x68 >> 2: 'Merchant', 0xF0 >> 2: 'Fighter',
         0xF4 >> 2: 'Cleric', 0xF8 >> 2: 'Wizard', 0xFC >> 2: 'Thief'}


def record(dump: pathlib.Path):
    b = dump.read_bytes()
    base = DS_SEG * 16
    if len(b) < base + OFF_KIND + SLOTS:
        return None
    g = lambda off: b[base + off: base + off + SLOTS]
    return {'x': g(OFF_X), 'hp': g(OFF_HP), 'type': g(OFF_TYPE), 'kind': g(OFF_KIND),
            'name': b[base + 0x36:base + 0x46].split(b'\x00')[0].decode('ascii', 'replace')}


def active(r):
    return [i for i in range(SLOTS)
            if r['type'][i] != EMPTY and (r['type'][i] or r['kind'][i])]


def verdict(r):
    """Classify how live HP relates to the arm base values."""
    act = active(r)
    eq = sum(1 for i in act if ARMS.get(r['type'][i]) == r['hp'][i])
    lo = sum(1 for i in act if isinstance(ARMS.get(r['type'][i]), int)
             and r['hp'][i] < ARMS[r['type'][i]])
    hi = sum(1 for i in act if isinstance(ARMS.get(r['type'][i]), int)
             and r['hp'][i] > ARMS[r['type'][i]])
    return act, eq, lo, hi


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument('--captures', default=os.path.join(PROJECT_ROOT, 'captures', 'spice86'))
    ap.add_argument('--detail', help='dump one capture slot by slot')
    a = ap.parse_args()
    root = pathlib.Path(a.captures)
    if not root.is_dir():
        sys.exit('no such directory: %s' % root)

    dumps = sorted(root.glob('*/spice86dumpMemoryDump.bin'))
    if not dumps:
        sys.exit('no memory dumps under %s' % root)

    if a.detail:
        p = root / a.detail / 'spice86dumpMemoryDump.bin'
        r = record(p) if p.exists() else None
        if r is None:
            sys.exit('no readable dump for %s' % a.detail)
        print('%s  player=%r' % (a.detail, r['name']))
        for i in active(r):
            t, h = r['type'][i], r['hp'][i]
            base = ARMS.get(t)
            rel = ('base=%s %s' % (base, 'eq' if base == h else
                                   ('below' if base and h < base else 'ABOVE'))) if base \
                else 'no arm'
            print('  slot %2d x=%2d type 0x%02X kind 0x%02X hp %3d  %-12s %s'
                  % (i, r['x'][i], t, r['kind'][i], h,
                     NAMES.get(t >> 2, '?'), rel))
        return

    print('%-24s %-9s %5s  %-26s %s' % ('capture', 'player', 'act', 'distinct HP',
                                         'live HP vs arm base'))
    clean = buffed = 0
    for d in dumps:
        r = record(d)
        if r is None:
            continue
        act, eq, lo, hi = verdict(r)
        if not act:
            print('%-24s %-9s %5s  %-26s %s' % (d.parent.name, '-', 0, '-', 'no monsters'))
            continue
        vals = sorted({r['hp'][i] for i in act})
        note = '%d eq / %d below / %d above' % (eq, lo, hi)
        if hi == 0 and lo == 0:
            clean += 1
            note += '   <- arms exact'
        if hi:
            buffed += 1
        print('%-24s %-9s %5s  %-26s %s'
              % (d.parent.name, r['name'][:9] or '-', len(act),
                 str(vals)[:26], note))
    print('\n%d dumps with monsters; %d match the arm bases exactly with no damage or '
          'buff; %d contain values ABOVE the base (area override)' % (clean + buffed, clean, buffed))
    print('Read the corpus before running a new capture — this answer was already here.')


if __name__ == '__main__':
    main()
