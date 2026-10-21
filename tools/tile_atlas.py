#!/usr/bin/env python3
"""tile_atlas.py — extract the 64 tile sprites from the exe as individual PNGs.

Purpose: give every art entry a stable visual identity so a description table can be
built from what the sprite actually looks like, instead of from a guess about its id.

The pixel decode (2bpp, 16x16, leftmost pixel in the top bits, CGA mode-4 palette)
is the same decode `tools/extract_tiles.py` uses. This tool deliberately re-verifies
the structural claims and FAILS LOUDLY rather than emitting a plausible-looking sheet,
because a silently wrong decode would poison every downstream description.

Output is GAME CONTENT and must never be committed: write it under tmp/ (gitignored).
The JSON sidecar is metadata about our own decode (offsets, colour usage, ascii grid),
but it is written next to the PNGs so it stays out of git too.

Usage:
    python3 tools/tile_atlas.py --out tmp/tiles
"""
import argparse
import json
import os
import struct
import sys

from PIL import Image, ImageDraw

# Structure proven in docs/phase4-implementation.md (owner-found index, verified
# by tools/extract_tiles.py): index table of 64 LE words at file 0x7BC0, stride 66,
# every entry preceded by a 04 10 header, first pixel offset 0x7C42.
IDX_OFF = 0x7BC0
PIX_OFF = 0x7C42
TILE_STRIDE = 66
TILE_BYTES = 64
N_TILES = 64
HEADER = (0x04, 0x10)

# CGA mode 4 palette: 0 black, 1 cyan, 2 magenta, 3 white.
PAL = [(0, 0, 0), (0, 170, 170), (170, 0, 170), (255, 255, 255)]
# Debug glyphs for the ascii grid, same mapping as extract_tiles.py.
GLYPH = {0: '.', 1: 'o', 2: 'x', 3: '#'}


def die(msg):
    print('FATAL: %s' % msg, file=sys.stderr)
    sys.exit(1)


def unpack(data, off):
    """64 bytes -> 16x16 grid of colour indices 0..3."""
    grid = []
    for row in range(16):
        line = []
        for b in range(4):
            byte = data[off + row * 4 + b]
            line += [(byte >> 6) & 3, (byte >> 4) & 3, (byte >> 2) & 3, byte & 3]
        grid.append(line)
    return grid


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--exe', default='original/ultimaii.exe')
    ap.add_argument('--out', default='tmp/tiles')
    ap.add_argument('--scale', type=int, default=8)
    args = ap.parse_args()

    data = open(args.exe, 'rb').read()
    if len(data) < IDX_OFF + 2 * N_TILES:
        die('%s is %d bytes, too small to hold the tile index at %s'
            % (args.exe, len(data), hex(IDX_OFF)))

    idx = list(struct.unpack('<%dH' % N_TILES, data[IDX_OFF:IDX_OFF + 2 * N_TILES]))
    base = PIX_OFF - 2 - idx[0]

    # --- verify, loudly -------------------------------------------------------
    offs = []
    for n in range(N_TILES):
        off = base + idx[n]
        if (data[off], data[off + 1]) != HEADER:
            die('tile %d at file %s header is %02X %02X, expected %02X %02X — '
                'the index assumption is wrong, refusing to render'
                % (n, hex(off), data[off], data[off + 1], *HEADER))
        offs.append(off + 2)
    steps = {offs[i + 1] - offs[i] for i in range(N_TILES - 1)}
    if steps != {TILE_STRIDE}:
        die('pixel stride is %s, expected {%d} — refusing to render'
            % (sorted(steps), TILE_STRIDE))
    if offs[0] != PIX_OFF:
        die('first pixel offset %s, expected %s — refusing to render'
            % (hex(offs[0]), hex(PIX_OFF)))

    shapes = {}
    records = []
    for n in range(N_TILES):
        px = data[offs[n]:offs[n] + TILE_BYTES]
        shapes.setdefault(px, []).append(n)
        g = unpack(data, offs[n])
        used = sorted({v for row in g for v in row})
        records.append({
            'id': n,
            'hex': '%02X' % n,
            'file_offset': hex(offs[n]),
            'colors_used': used,
            'color_names': [{0: 'black', 1: 'cyan', 2: 'magenta', 3: 'white'}[c]
                            for c in used],
            'ascii': [''.join(GLYPH[v] for v in row) for row in g],
            'description': '',   # filled in by the vision pass, by hand
            'glyph': '',         # single display char chosen for the map renderer
            'glyph_conflict': '',
        })

    dupes = {k: v for k, v in shapes.items() if len(v) > 1}
    print('%s: %d tiles, %d distinct pixel shapes, headers all %02X %02X, stride %d'
          % (args.exe, N_TILES, len(shapes), *HEADER, TILE_STRIDE))
    if dupes:
        print('NOTE duplicate shapes: %s' % [[hex(x) for x in v] for v in dupes.values()])

    out = args.out
    os.makedirs(out, exist_ok=True)

    # --- individual PNGs ------------------------------------------------------
    for n in range(N_TILES):
        g = unpack(data, offs[n])
        img = Image.new('RGB', (16 * args.scale, 16 * args.scale))
        px = img.load()
        for y in range(16):
            for x in range(16):
                c = PAL[g[y][x]]
                for dy in range(args.scale):
                    for dx in range(args.scale):
                        px[x * args.scale + dx, y * args.scale + dy] = c
        img.save(os.path.join(out, 'tile_%02X.png' % n))

    # --- labelled contact sheet ----------------------------------------------
    cols = 8
    rows = (N_TILES + cols - 1) // cols
    cell = 16 * args.scale
    pad = 14
    sheet = Image.new('RGB', (cols * cell, rows * (cell + pad)), (32, 32, 32))
    draw = ImageDraw.Draw(sheet)
    for n in range(N_TILES):
        g = unpack(data, offs[n])
        tx, ty = (n % cols) * cell, (n // cols) * (cell + pad)
        for y in range(16):
            for x in range(16):
                c = PAL[g[y][x]]
                for dy in range(args.scale):
                    for dx in range(args.scale):
                        sheet.putpixel((tx + x * args.scale + dx,
                                        ty + pad + y * args.scale + dy), c)
        draw.text((tx + 2, ty + 1), '%02X' % n, fill=(255, 255, 0))
    sheet.save(os.path.join(out, 'atlas.png'))

    with open(os.path.join(out, 'tiles.json'), 'w') as fh:
        json.dump({'exe': args.exe, 'exe_bytes': len(data), 'tiles': records}, fh, indent=1)

    print('wrote %s/tile_00.png..tile_%02X.png, atlas.png, tiles.json'
          % (out, N_TILES - 1))
    print('game content — keep under tmp/, never commit')


if __name__ == '__main__':
    main()
