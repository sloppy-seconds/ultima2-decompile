#!/usr/bin/env python3
"""monx_layout_scan.py — does the five-array `monxNN` layout hold in every sector?

`docs/monster-spawn.md` § 2 established the layout on two sectors (00 and 03) only.
This re-checks it against every capture on disk, per sector, and prints where it
holds and where it does not.

The claim under test: `monxNN` is five parallel 32-byte arrays, one entry per monster
slot, and they land in the data segment at a fixed stride of 0x20:

    monxNN[  0.. 31] -> DS:0x137 + i   x
    monxNN[ 32.. 63] -> DS:0x157 + i   y
    monxNN[ 64.. 95] -> DS:0x177 + i   HP
    monxNN[ 96..127] -> DS:0x197 + i   type
    monxNN[128..159] -> DS:0x1B7 + i   kind

x and y are expected to drift, because the file holds spawn positions and monsters
move. HP may sit below the file value, because damage lowers it; it must never sit
above. type and kind are static and must match exactly. Those three rules are what
this checks, and a sector that breaks the last two breaks the layout.

Sector is read from the live record (DS:49 tens, DS:4A ones, two decimal digits),
not from the capture directory name -- `docs/monster-spawn.md` § 5 records that
directory names lie.

Read-only.

Usage:
    python3 tools/monx_layout_scan.py                # per-sector table
    python3 tools/monx_layout_scan.py --by-capture   # one row per capture
"""
import argparse
import collections
import os
import pathlib
import sys

DS_SEG = 0x08BE
SLOTS = 32
# (field, monx offset, DS offset)
FIELDS = [('x', 0, 0x137), ('y', 32, 0x157), ('hp', 64, 0x177),
          ('type', 96, 0x197), ('kind', 128, 0x1B7), ('flag', 160, 0x1D7)]
# The overworld empty-slot sentinel. A dungeon record holds 0x01..0x07 in `type`
# and slot>>1 in `kind`, so the monx comparison is meaningless there and those
# captures are reported separately rather than scored. (docs/monster-spawn.md § 7)
DUNGEON_TYPES = set(range(1, 8))


def read(path):
    b = path.read_bytes()
    base = DS_SEG * 16
    if len(b) < base + 0x200:
        return None
    g = lambda off: [b[base + off + i] for i in range(SLOTS)]
    return {'x': g(0x137), 'y': g(0x157), 'hp': g(0x177), 'type': g(0x197),
            'kind': g(0x1B7), 'flag': g(0x1D7),
            'sector': '%d%d' % (b[base + 0x49], b[base + 0x4A]),
            'name': b[base + 0x36:base + 0x46].split(b'\x00')[0]
                   .decode('ascii', 'replace')}


def is_dungeon(rec):
    act = [i for i in range(SLOTS) if rec['type'][i]]
    return bool(act) and all(rec['type'][i] in DUNGEON_TYPES for i in act) \
        and all(rec['kind'][i] == (i >> 1) for i in act)


def score(rec, monx):
    """Per-field (match, mismatch, populated, note).

    Only slots the file actually authors are scored: a slot with `monx[96+i] == 0`
    holds no placed monster, so whatever the live record holds there came from a
    wandering spawn and is not the file's business. Scoring those slots is what made
    sector 20 -- whose `monx20` is all zeros -- look like a total layout failure.
    """
    authored = [i for i in range(SLOTS) if monx[96 + i] != 0]
    out = {}
    for name, moff, doff in FIELDS:
        live = rec[name]
        file_ = list(monx[moff:moff + SLOTS])
        pop = authored
        ok = bad = 0
        worst = ''
        for i in pop:
            if live[i] == file_[i]:
                ok += 1
                continue
            bad += 1
            if name == 'hp' and live[i] > file_[i]:
                worst = 'HP ABOVE the file value -- impossible under damage-only drift'
            elif name in ('type', 'kind') and not worst:
                worst = '%s differs at slot %d (file 0x%02X, live 0x%02X)' % (
                    name, i, file_[i], live[i])
        out[name] = (ok, bad, len(pop), worst)
    return out


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument('--captures', default='captures/spice86')
    ap.add_argument('--monx', default='original')
    ap.add_argument('--by-capture', action='store_true')
    a = ap.parse_args()

    root = pathlib.Path(a.captures)
    if not root.is_dir():
        sys.exit('no such directory: %s' % root)

    per_sector = collections.defaultdict(lambda: collections.Counter())
    sector_captures = collections.defaultdict(set)
    dungeon_caps, rows = [], []
    for d in sorted(root.iterdir()):
        p = d / 'spice86dumpMemoryDump.bin'
        if not p.is_file():
            continue
        rec = read(p)
        if rec is None:
            continue
        if not any(rec['type']) and not any(rec['kind']):
            continue
        if is_dungeon(rec):
            dungeon_caps.append((d.name, rec['sector']))
            continue
        mp = pathlib.Path(a.monx) / ('monx%s' % rec['sector'])
        if not mp.is_file():
            rows.append((d.name, rec['sector'], None, 'no monx%s on disk' % rec['sector']))
            continue
        s = score(rec, mp.read_bytes())
        rows.append((d.name, rec['sector'], s, ''))
        sector_captures[rec['sector']].add(d.name)
        for name, (ok, bad, pop, worst) in s.items():
            per_sector[rec['sector']][name + '_ok'] += ok
            per_sector[rec['sector']][name + '_bad'] += bad
            if worst:
                per_sector[rec['sector']][name + '_note'] = worst

    if a.by_capture:
        print('%-26s %-6s %s' % ('capture', 'sector', 'per-field ok/bad'))
        for name, sec, s, note in rows:
            if s is None:
                print('%-26s %-6s %s' % (name, sec, note))
                continue
            print('%-26s %-6s %s' % (name, sec, '  '.join(
                '%s %d/%d' % (f, s[f][0], s[f][1] + s[f][0]) for f, _, _ in FIELDS)))
    else:
        print('monx six-array layout, aggregated over every non-dungeon capture')
        print('')
        print('%-6s %-4s %-14s %-14s %-18s %-14s %-14s %-14s %s' % (
            'sector', 'caps', 'x (drifts)', 'y (drifts)', 'HP (never above)',
            'type', 'kind', 'flag', 'notes'))
        for sec in sorted(per_sector):
            c = per_sector[sec]
            def cell(f):
                ok, bad = c[f + '_ok'], c[f + '_bad']
                return '%d/%d' % (ok, ok + bad) + (' !' if bad else '')
            flags = []
            for f in ('type', 'kind', 'flag'):
                if c[f + '_bad']:
                    flags.append('%s: %d mismatch%s (%s)' % (
                        f, c[f + '_bad'], 'es' if c[f + '_bad'] > 1 else '',
                        c[f + '_note']))
            if c['hp_bad'] and 'ABOVE' in str(c.get('hp_note', '')):
                flags.append('hp above file value')
            print('%-6s %-4d %-14s %-14s %-18s %-14s %-14s %-14s %s' % (
                sec, len(sector_captures[sec]), cell('x'), cell('y'), cell('hp'),
                cell('type'), cell('kind'), cell('flag'), '; '.join(flags)))
    if dungeon_caps:
        print('\nnot scored (dungeon encoding, no monx correlation -- '
              'docs/monster-spawn.md § 7): %s'
              % ', '.join('%s[%s]' % t for t in dungeon_caps))
    missing = sorted({r[1] for r in rows if r[2] is None})
    if missing:
        print('captures whose sector has no monx file: %s' % ', '.join(missing))
    return 0


if __name__ == '__main__':
    sys.exit(main())
