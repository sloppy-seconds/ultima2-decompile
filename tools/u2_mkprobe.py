#!/usr/bin/env python3
"""Generate a synthetic Ultima II sector map for passability probing.

Why: real sector maps make this slow and incomplete. Rare bytes appear 2-7 times,
often walled off behind water or mountains, so you cannot reach them to step into
them. A probe map puts every byte value next to walkable ground in one sector, so
a single continuous walk measures the whole table.

Map file layout, measured from original/mapx*:
    bytes 0..4095    64x64 grid, one byte per tile, row-major
    byte  4096       always 0x1A (marker; present in all 33 sector maps)
    bytes 4097..4223 mostly zero; 25 distinct variants across the 33 maps

Terrain bytes are always multiples of 4, 0x00..0xFC = 64 values, and
art_index = map_byte >> 2 into the 64-entry tile atlas.

The generator fills the map with a passable background and lays two probe rows,
each probe isolated so stepping into it tests exactly one byte.

NEVER writes into original/ or references/. Output path is required.
"""
import argparse
import sys

GRID = 64 * 64
TAIL = b'\x1a' + b'\x00' * 127
BACKGROUND = 0x08          # grass, measured passable
PROBE_BYTES = [b for b in range(0x00, 0x100, 4)]   # 64 values


def build(rows):
    """rows: list of (probe_y, corridor_y, start_x, [bytes...])"""
    g = bytearray([BACKGROUND]) * GRID
    for probe_y, corridor_y, start_x, vals in rows:
        for i, b in enumerate(vals):
            g[probe_y * 64 + start_x + i] = b
    return bytes(g) + TAIL


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('-o', '--out', required=True, help='output path (must not be original/ or references/)')
    ap.add_argument('--probe-y', type=int, nargs='*', default=[31, 19])
    ap.add_argument('--corridor-y', type=int, nargs='*', default=[32, 20])
    ap.add_argument('--start-x', type=int, default=16,
                    help='first probe column; keep probes off the map edge so the '
                         'walk never crosses a toroidal wrap and loses track')
    a = ap.parse_args()

    low = a.out.lower()
    if '/original/' in low or '/references/' in low:
        sys.exit('refusing to write into original/ or references/')

    rows = len(a.probe_y)
    if rows != len(a.corridor_y):
        sys.exit('need one corridor-y per probe-y')
    per = len(PROBE_BYTES) // rows
    if a.start_x + per > 64:
        sys.exit('start-x %d + %d probes exceeds the 64-column map' % (a.start_x, per))
    plan = []
    for n, (py, cy) in enumerate(zip(a.probe_y, a.corridor_y)):
        vals = PROBE_BYTES[n * per:(n + 1) * per]
        plan.append((py, cy, a.start_x, vals))

    data = build(plan)
    with open(a.out, 'wb') as f:
        f.write(data)

    print('wrote %s (%d bytes)' % (a.out, len(data)))
    for py, cy, sx, vals in plan:
        print('  probe row y=%d (corridor y=%d): %d probes, x=%d..%d, bytes 0x%02X..0x%02X'
              % (py, cy, len(vals), sx, sx + len(vals) - 1, vals[0], vals[-1]))
    print('\nwalk plan: stand on corridor y, step Up into probe at (x, probe_y), step back Down.')


if __name__ == '__main__':
    main()
