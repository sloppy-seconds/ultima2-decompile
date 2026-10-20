#!/usr/bin/env python3
"""extract_tiles.py — pull the 16x16 tile art out of ultimaii.exe and render it.

Output is GAME CONTENT: it must never be committed. It is written under tmp/,
which is gitignored, and the licensing rule in AGENTS.md applies to it.

Claim under test (owner, 2026-10-27):
  * index table at file 0x7BC0: 64 little-endian words, first = 0x0630, stride 66
  * tile N pixels at 0x7C42 + 66*N, each preceded by a 2-byte header (04 10)
  * one tile = 64 bytes = 16 rows x 4 bytes, 2bpp, leftmost pixel in the top bits
  * colour indices 0..3 = CGA black, cyan, magenta, white
"""
import struct
import sys
from PIL import Image

import argparse

ap = argparse.ArgumentParser()
ap.add_argument('--exe', default='original/ultimaii.exe')
ap.add_argument('--out', default='tmp/tiles.png')
ap.add_argument('--scale', type=int, default=8)
args = ap.parse_args()
EXE = args.exe
IDX_OFF = 0x7BC0
PIX_OFF = 0x7C42
TILE_STRIDE = 66
TILE_BYTES = 64
N_TILES = 64

data = open(EXE, 'rb').read()
print('exe size', len(data), hex(len(data)))

# --- 1. the index table -------------------------------------------------
raw = data[IDX_OFF:IDX_OFF + 2 * N_TILES]
idx = list(struct.unpack('<64H', raw))
print('\nindex table @ %s: first 8 = %s' % (hex(IDX_OFF), [hex(v) for v in idx[:8]]))
print('  last 4 = %s' % [hex(v) for v in idx[-4:]])
diffs = {idx[i + 1] - idx[i] for i in range(N_TILES - 1)}
print('  distinct consecutive deltas:', sorted(diffs))
print('  first entry == 0x0630:', idx[0] == 0x0630)

# The index values are offsets in some base; derive the base from the constraint
# that entry 0 points at the 2-byte header immediately before PIX_OFF.
base = PIX_OFF - 2 - idx[0]
print('  implied base file offset: %s' % hex(base))

# --- 2. every tile resolves and carries the claimed header --------------
bad = []
for n in range(N_TILES):
    off = base + idx[n]
    if data[off] != 0x04 or data[off + 1] != 0x10:
        bad.append((n, hex(off), data[off], data[off + 1]))
print('  tiles whose header is not 04 10:', len(bad), bad[:3])
offs = [base + idx[n] + 2 for n in range(N_TILES)]
print('  pixel offsets step by 66 for every tile:',
      all(offs[i + 1] - offs[i] == TILE_STRIDE for i in range(N_TILES - 1)))
print('  first pixel offset %s (claim: %s)' % (hex(offs[0]), hex(PIX_OFF)))

# --- 3. decode a tile ---------------------------------------------------
def unpack(px, off):
    """64 bytes -> 16x16 grid of colour indices 0..3."""
    grid = []
    for row in range(16):
        line = []
        for b in range(4):
            byte = px[off + row * 4 + b]
            line += [(byte >> 6) & 3, (byte >> 4) & 3, (byte >> 2) & 3, byte & 3]
        grid.append(line)
    return grid


CH = {0: '.', 1: 'o', 2: 'x', 3: '#'}
for n in (0, 1, 2, 8, 16):
    g = unpack(data, offs[n])
    used = sorted({v for row in g for v in row})
    print('\ntile %d @ %s  colours used %s' % (n, hex(offs[n]), used))
    for row in g:
        print('   ' + ''.join(CH[v] for v in row))

# --- 4. render all 64 tiles, scaled 8x ----------------------------------
PAL = [(0, 0, 0), (0, 170, 170), (170, 0, 170), (255, 255, 255)]
SCALE = args.scale
cols = 8
rows = (N_TILES + cols - 1) // cols
sheet = Image.new('RGB', (cols * 16 * SCALE, rows * 16 * SCALE), (40, 40, 40))
for n in range(N_TILES):
    g = unpack(data, offs[n])
    tx, ty = (n % cols) * 16 * SCALE, (n // cols) * 16 * SCALE
    for y in range(16):
        for x in range(16):
            c = PAL[g[y][x]]
            for dy in range(SCALE):
                for dx in range(SCALE):
                    sheet.putpixel((tx + x * SCALE + dx, ty + y * SCALE + dy), c)
import os
os.makedirs(os.path.dirname(args.out) or '.', exist_ok=True)
out = args.out
sheet.save(out)
print('\nwrote %s (%s) — game content, gitignored, never committed' % (out, sheet.size))
