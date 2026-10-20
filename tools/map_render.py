#!/usr/bin/env python3
"""Render the overworld sector from a Spice86 memory dump.

The sector map lives at DS:[DS:0x472] as 64x64 tile bytes, with the player and
every monster stamped into it, so a single memory snapshot yields the whole
tactical picture: terrain, the water ring, land bridges, and monster positions.

Monster arrays are three parallel byte arrays at stride 1, 32 slots:
    x      = DS:0x137 + i
    y      = DS:0x157 + i
    tile   = DS:0x1B7 + i     the byte stamped into the map (appearance)
    kind   = DS:0x197 + i     drives loot and behaviour; the reward switch
                              branches on 0x60 / 0xFC / 0xF0 / 0xF8
An earlier note called 0x197 an "active" flag with a 0x40 sentinel; live values
of 0x00, 0xFC, 0x30 and 0x2C disproved that.

Usage: tools/map_render.py <memorydump.bin> [--ds 0x08BE] [--legend]
"""
import argparse
import sys
from collections import Counter

GLYPH = {
    0x00: "~",   # water - measured BLOCKED on foot
    0x04: ",",
    0x08: ".",   # measured passable
    0x0C: '"',   # measured passable
    0x10: "^",
    0x18: "v",
    0x20: "=",
    0x24: "A",
}
# monster kinds seen live, so the map can distinguish them at a glance
KIND_MARK = {0xFC: "M", 0xF0: "T", 0xF8: "R", 0x60: "K"}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("dump")
    ap.add_argument("--ds", default="0x08BE")
    ap.add_argument("--legend", action="store_true")
    args = ap.parse_args()

    dump = open(args.dump, "rb").read()
    base = int(args.ds, 16) * 16
    if base + 0x2800 > len(dump):
        sys.exit(f"dump too small: need {hex(base + 0x2800)}, have {hex(len(dump))}")

    st = dump[base:base + 0x600]
    px, py = st[0], st[1]
    mb = st[0x472] + (st[0x473] << 8)
    mp = dump[base + mb: base + mb + 4096]
    if len(mp) < 4096:
        sys.exit("map buffer runs past the dump")

    mons = []
    for i in range(32):
        x, y = st[0x137 + i], st[0x157 + i]
        if x or y:
            mons.append((i, x, y, st[0x1B7 + i], st[0x197 + i]))

    print(f"player=({px},{py})  map buffer=DS:{mb:04X}  "
          f"sector hi/lo=DS:49/4A={st[0x49]:02X}/{st[0x4A]:02X}")
    print(f"monsters live: {len(mons)}")
    for i, x, y, tile, kind in mons:
        print(f"  [{i:2d}] ({x:2d},{y:2d}) tile=0x{tile:02X} kind=0x{kind:02X}")

    grid = [[GLYPH.get(mp[y * 64 + x], "?") for x in range(64)]
            for y in range(64)]
    for i, x, y, tile, kind in mons:
        if 0 <= x < 64 and 0 <= y < 64:
            grid[y][x] = KIND_MARK.get(kind, "M")
    if 0 <= px < 64 and 0 <= py < 64:
        grid[py][px] = "@"

    print("\n    " + "".join(str((x // 10) % 10) for x in range(64)))
    for y, row in enumerate(grid):
        print(f"{y:3d}  " + "".join(row))

    if args.legend:
        print("\ntile census:", dict(Counter(f"0x{b:02x}" for b in mp).most_common(12)))
        print("glyphs: ~ water(blocked)  . and \" passable  ^ v = A unmeasured"
              "  ? unknown   @ player   M/T/R/K monster by kind")


if __name__ == "__main__":
    main()
