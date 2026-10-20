#!/usr/bin/env python3
"""Prototype the CP4 render path in Python before writing C.

Derived from asm (runtime addresses; file = runtime + 0x200):

  asm/5AE1..5B6C  fill loop
    top-left map cell   = (x - 9, y - 5)          [DS:00, DS:01]
    viewport            = 20 cols x 10 rows       (cmp $0x14 / cmp $0xa)
    tile index          = (map_byte >> 1) & 0xFE  (clc; rcr al,1; and al,0xfe)
    out of sector       -> tile value from DS:12
    underlay match      -> bit 7 set = do not draw

  asm/4ABB  flush loop: reads [DS:272+i], skips bit 7, indexes [DS:5B0+id]
  asm/4A74  blit: skip 2-byte header, 16 rows x 4 bytes, 2bpp
"""
import struct
from PIL import Image

EXE = 'original/ultimaii.exe'
exe = open(EXE, 'rb').read()

# --- tile art (proven earlier) ---
IDX = 0x7BC0
idx = struct.unpack('<64H', exe[IDX:IDX + 128])
base = 0x7C42 - 2 - idx[0]
tiles = []
for n in range(64):
    off = base + idx[n] + 2
    g = []
    for r in range(16):
        row = []
        for b in exe[off + r * 4: off + r * 4 + 4]:
            row += [(b >> 6) & 3, (b >> 4) & 3, (b >> 2) & 3, b & 3]
        g.append(row)
    tiles.append(g)

# --- live DS capture: where was the player actually standing? ---
ds = open('captures/spice86/live-ds-4f4d.bin', 'rb').read()
px, py = ds[0x00], ds[0x01]
print('live DS: x=%d y=%d  DS:49=%#x DS:4A=%#x DS:12=%#x DS:6E=%#x'
      % (px, py, ds[0x49], ds[0x4A], ds[0x12], ds[0x6E]))

import os, glob
cands = sorted(glob.glob('original/[Mm][Aa][Pp][XxGg]*'))
print('map files present:', len(cands))


def load_sector(name):
    p = 'original/' + name
    d = open(p, 'rb').read()
    return d[:4096]


def render(mapname, x, y, cols=20, rows=10):
    m = load_sector(mapname)
    ox, oy = x - 9, y - 5           # top-left map cell
    grid = [[0] * cols for _ in range(rows)]
    for r in range(rows):
        for c in range(cols):
            mx, my = ox + c, oy + r
            if not (0 <= mx < 64 and 0 <= my < 64):
                tile = ds[0x12]
            else:
                tile = m[my * 64 + mx]
            grid[r][c] = (tile >> 1) & 0xFE
    return grid


def draw(grid, scale=1):
    w, h = len(grid[0]) * 16, len(grid) * 16
    img = Image.new('RGB', (w * scale, h * scale))
    PAL = [(0, 0, 0), (0, 170, 170), (170, 0, 170), (255, 255, 255)]
    for r in range(len(grid)):
        for c in range(len(grid[0])):
            t = tiles[grid[r][c] % 64]
            for yy in range(16):
                for xx in range(16):
                    col = PAL[t[yy][xx]]
                    for dy in range(scale):
                        for dx in range(scale):
                            img.putpixel(((c * 16 + xx) * scale + dx,
                                          (r * 16 + yy) * scale + dy), col)
    return img


# index histogram of a sector, to see which tile ids dominate
for name in ('mapx00', 'MAPX00', 'mapx44', 'MAPX44'):
    if os.path.exists('original/' + name):
        m = load_sector(name)
        hist = {}
        for b in m:
            hist[(b >> 1) & 0xFE] = hist.get((b >> 1) & 0xFE, 0) + 1
        top = sorted(hist.items(), key=lambda kv: -kv[1])[:6]
        print('%s raw top bytes %s -> tile ids %s' %
              (name, sorted({b: 1 for b in m}, key=lambda b: -m.count(b))[:5], top))
        g = render(name, 32, 32)
        draw(g, 2).save('tmp/proto_%s.png' % name.lower())
        print('  wrote tmp/proto_%s.png' % name.lower())
