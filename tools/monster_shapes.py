#!/usr/bin/env python3
"""monster_shapes.py — render the overworld sprite for each observed monster type.

There is no monster *name* table in the executable (the string THIEF at file
0x50FE is a *player class*, not a monster). So a monster type can only be put a
face to by rendering the art it draws. Two data sources exist and they are NOT
the same thing; this tool reports both:

1. The OVERWORLD monster sprite is a tile from the 64-record tile-art table in
   the executable (the same table tools/extract_tiles.py proves and renders).
   The art index is `monster_type >> 2`. This is not a guess: the live finding in
   docs/spice86-live-findings.md S12 records that map byte 0x34 is "art 0x0D, a
   humanoid figure with arms raised", and 0x34 >> 2 == 0x0D. The overworld grid
   cell of a monster holds its type byte (see T5/T6), and the tile path draws
   art = index, so the type->art transform is the >>2 here.

2. The `original/monsters` file (2176 bytes = 64 records x 34 bytes) is a list
   of (byte0, byte1) coordinate PAIRS, not names and not a bitmap. It is loaded
   at DS:2900 (measured: the file's bytes appear at DS:2900 in every live DS
   dump, record r at DS:2900 + r*34). Its records do not resolve to a
   recognisable 16x16 sprite as a point cloud (see --monsters-layout output), so
   its exact rendering semantics are NOT proven here; it is reported as layout
   evidence only. The dungeon is a wireframe renderer, so these pairs are the
   likely home of the dungeon monster outlines, but that is inferred, not proven.

RADIX: monster types are DECIMAL in the source findings (48, 52, ...). 48 decimal
is 0x30, not 0x48. Both are printed everywhere here to keep the radix explicit
(AGENTS.md / the overnight report both record a radix misread).

Output PNGs are GAME CONTENT and are written under tmp/ (gitignored). The ASCII
render goes to stdout so the finding is reviewable without the image.
"""
import argparse
import os
import struct
import sys

# --- tile-art table location (proven by tools/extract_tiles.py) --------------
IDX_OFF = 0x7BC0      # 64 little-endian words, stride 66, first == 0x0630
PIX_OFF = 0x7C42      # pixels of tile 0 (each tile preceded by a 04 10 header)
TILE_STRIDE = 66
N_TILES = 64
PAL = [(0, 0, 0), (0, 170, 170), (170, 0, 170), (255, 255, 255)]  # CGA blk/cyan/mag/white
CH = {0: '.', 1: 'o', 2: 'x', 3: '#'}

# Monster types observed live on 2026-10-21 (docs/spice86-live-findings.md S12).
# DECIMAL value, hex, and the behaviour that identifies it (special-attack asm).
OBSERVED = [
    (48,  0x30, ""),
    (52,  0x34, "LEGS caster (asm/0E70)"),
    (56,  0x38, "ARMS caster (asm/0EC2)"),
    (60,  0x3C, "SLEEP caster (asm/0F48)"),
    (64,  0x40, "THIEF (asm/0FCD)"),
    (96,  0x60, ""),
    (104, 0x68, ""),
    (240, 0xF0, ""),
    (244, 0xF4, ""),
    (248, 0xF8, "MAGIC MISSILE caster (asm/0F12)"),
    (252, 0xFC, ""),
]


def load_tile_offsets(data):
    """Return the file offset of each tile's 64 pixel bytes (header skipped)."""
    idx = list(struct.unpack('<64H', data[IDX_OFF:IDX_OFF + 2 * N_TILES]))
    base = PIX_OFF - 2 - idx[0]          # derive base so tile 0 lands on PIX_OFF
    offs = [base + idx[n] + 2 for n in range(N_TILES)]
    # fail loudly if the table is not the one extract_tiles.py proved
    if idx[0] != 0x0630:
        sys.exit(f"tile index[0]={idx[0]:#06x} != 0x0630: wrong exe or wrong table")
    for n in range(N_TILES):
        if data[offs[n] - 2] != 0x04 or data[offs[n] - 1] != 0x10:
            sys.exit(f"tile {n} header is not 04 10 at {offs[n]-2:#06x}: table moved")
    return offs


def unpack(px, off):
    """64 bytes -> 16x16 grid of colour indices 0..3 (2bpp, top bits = leftmost)."""
    grid = []
    for row in range(16):
        line = []
        for b in range(4):
            byte = px[off + row * 4 + b]
            line += [(byte >> 6) & 3, (byte >> 4) & 3, (byte >> 2) & 3, byte & 3]
        grid.append(line)
    return grid


def ascii_tile(grid):
    return ["  " + "".join(CH[v] for v in row) for row in grid]


def monsters_layout(path):
    """Report the `monsters` file layout evidence (no shape claim)."""
    data = open(path, "rb").read()
    lines = []
    lines.append(f"monsters file: {len(data)} bytes = {len(data)//34} records x 34 "
                 f"(remainder {len(data)%34}); loaded at DS:2900, record i at DS:2900 + i*34")
    empty = [r for r in range(len(data)//34) if not any(data[r*34:(r+1)*34])]
    lines.append(f"  {len(empty)} of {len(data)//34} records are all-zero: {empty}")
    xs, ys = [], []
    for r in range(len(data)//34):
        rec = data[r*34:(r+1)*34]
        for i in range(0, 34, 2):
            if (rec[i], rec[i+1]) != (0, 0):
                xs.append(rec[i]); ys.append(rec[i+1])
    lines.append(f"  coordinate-pair ranges: byte0 {min(xs)}..{max(xs)}  byte1 {min(ys)}..{max(ys)}")
    lines.append("  records are (byte0,byte1) coordinate PAIRS, not names and not a bitmap;")
    lines.append("  they do not resolve to a recognisable 16x16 sprite as a point cloud, so the")
    lines.append("  rendering semantics are UNPROVEN (likely dungeon wireframe vertices - inferred).")
    return "\n".join(lines)


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--exe', default='original/ultimaii.exe')
    ap.add_argument('--monsters', default='original/monsters')
    ap.add_argument('--out', default='tmp/monster_shapes.png')
    ap.add_argument('--scale', type=int, default=8)
    ap.add_argument('--monsters-layout', action='store_true',
                    help='print only the monsters-file layout evidence and exit')
    args = ap.parse_args()

    if args.monsters_layout:
        print(monsters_layout(args.monsters))
        return

    data = open(args.exe, 'rb').read()
    offs = load_tile_offsets(data)

    print("Overworld monster sprites: art index = monster_type >> 2 "
          "(tile-art table, tools/extract_tiles.py).")
    print("Radix: types are DECIMAL (source findings); hex shown in parens.\n")
    cells = []
    for dec, hx, label in OBSERVED:
        art = dec >> 2
        grid = unpack(data, offs[art])
        head = f"type {dec:3d} (0x{hx:02X}) -> art {art:2d} (0x{art:02X})  {label}"
        print(head)
        for line in ascii_tile(grid):
            print(line)
        print()
        cells.append((head, grid))

    # contact sheet PNG (game content -> tmp/, gitignored)
    try:
        from PIL import Image
    except ImportError:
        print("PIL not available: ASCII above is the full result; skipping PNG.")
        return
    scale, tw = args.scale, 16
    cols = 4
    rows = (len(cells) + cols - 1) // cols
    label_h = 14
    sheet = Image.new('RGB', (cols * tw * scale, rows * (tw * scale + label_h)), (40, 40, 40))
    for i, (head, grid) in enumerate(cells):
        tx, ty = (i % cols) * tw * scale, (i // cols) * (tw * scale + label_h)
        for y in range(tw):
            for x in range(tw):
                c = PAL[grid[y][x]]
                for dy in range(scale):
                    for dx in range(scale):
                        sheet.putpixel((tx + x * scale + dx, ty + label_h + y * scale + dy), c)
    os.makedirs(os.path.dirname(args.out) or '.', exist_ok=True)
    sheet.save(args.out)
    print(f"wrote {args.out} ({sheet.size}) - game content, gitignored, never committed")
    print("\n" + monsters_layout(args.monsters))


if __name__ == '__main__':
    main()
