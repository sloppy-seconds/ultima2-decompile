#!/usr/bin/env python3
"""Emit a synthetic content directory for the CP6 commerce gate.

Engine-authored filler, same rule cp5_fight_seed.py follows: a gate that needs a shop
on a map must not depend on the player's own game files, and CI has no copy of them.
The bytes are shaped like the real ones because the engine reads them the same way.

What the geometry has to reproduce is the ray, not a town. asm/4050 steps one cell in the
aimed direction, requires that cell to be a shop sign (high-bit tile) or 0x7C, steps a
second cell and requires 0x68. So each case is three cells in a line: player, sign, marker.

The quadrant decides the shop (asm/1590), so the marker's position is not incidental —
putting the same geometry in the north-west half of a town yields the weapons shoppe and
nothing else about the cells changes.

Usage: cp6_commerce_seed.py DIR CASE
  CASE = armour | weapons | transport | grocery | pub | nomark
"""
import os
import sys

FLOOR = 0x70          # town paving, walkable, and what the live grid shows under a foot
SIGN = 0xB8           # a shop-sign letter: high bit set, which is what makes asm/407F skip
MARK = 0x68           # the merchant marker asm/409F requires
COUNTER = 0x7C        # the one non-high-bit tile the near cell also accepts

# case -> (sector digits, player cell, near cell, far cell, near tile, far tile)
#
# The last two are what make the refusal cases refusal cases: the ray needs the near cell
# to be a sign or 0x7C AND the far cell to be 0x68, and each of the two negative cases
# breaks exactly one of them.
CASES = {
    # sector 32 is a town (kind 2). North-east half -> the armour shoppe, which is the
    # one purchase this project has reproduced end to end more than once.
    "armour":    ((3, 2), (38, 5), (38, 4), (38, 3), SIGN, MARK),
    "weapons":   ((3, 2), (9, 5),  (9, 4),  (9, 3),  SIGN, MARK),
    "transport": ((3, 2), (38, 40), (38, 39), (38, 38), SIGN, MARK),
    # The pub is dispatched and NOT implemented, so the gate asserts it stays silent.
    "pub":       ((3, 2), (9, 40), (9, 39), (9, 38), SIGN, MARK),
    # sector 31 is a village (kind 1). North-east half -> the grocery. The cells mirror
    # the real sector-31 geometry measured on 2026-10-29: marker (55,19), 0x7C at
    # (55,20), player (55,21).
    "grocery":   ((3, 1), (55, 21), (55, 20), (55, 19), COUNTER, MARK),
    # Near cell is plain floor: asm/4081 rejects before the marker is ever consulted.
    "nosign":    ((3, 2), (38, 5), (38, 4), (38, 3), FLOOR, MARK),
    # Marker missing one cell further out: asm/409F rejects.
    "nomarker":  ((3, 2), (38, 5), (38, 4), (38, 3), SIGN, FLOOR),
}


def main(out_dir: str, case: str) -> int:
    (hi, lo), (px, py), (nx, ny), (fx, fy), ntile, ftile = CASES[case]

    content = os.path.join(out_dir, "content")
    save = os.path.join(out_dir, "save")
    os.makedirs(content, exist_ok=True)
    os.makedirs(save, exist_ok=True)

    sector = f"{hi}{lo}"
    grid = bytearray([FLOOR]) * 4096
    grid[ny * 64 + nx] = ntile
    grid[fy * 64 + fx] = ftile
    with open(os.path.join(content, f"mapx{sector}"), "wb") as f:
        f.write(bytes(grid))

    # An empty monx: the creature scan at asm/23E6 must come up empty so the ray takes the
    # map-tile path. A creature on the cursor is the talking branch, which is not modelled.
    with open(os.path.join(content, f"monx{sector}"), "wb") as f:
        f.write(bytes(256))

    p = bytearray(384)
    p[0:7] = b"BUYTEST"                      # name at DS:36
    p[0x49 - 0x36] = hi                      # sector digits: the second one IS the site kind
    p[0x4A - 0x36] = lo
    p[0x4E - 0x36] = 0x40                    # charisma
    p[0x50 - 0x36] = 0x40                    # intelligence
    p[0x51 - 0x36] = 0x99
    p[0x52 - 0x36] = 0x99                    # HP 9999
    p[0x53 - 0x36] = 0x50
    p[0x54 - 0x36] = 0x00                    # food 5000, so a grocery buy is visible
    p[0x55 - 0x36] = 0x00
    p[0x56 - 0x36] = 0x99
    p[0x57 - 0x36] = 0x99                    # EXP 9999
    p[0x58 - 0x36] = 0x99
    p[0x59 - 0x36] = 0x99                    # GOLD 9999
    p[0x5A - 0x36] = px                      # entry cell: where the world drops you
    p[0x5B - 0x36] = py
    # Command-letter cases need the inventories the handlers gate on. All three are ordinary
    # save bytes (file offset = DS - 0x36), and each one is the byte the handler actually reads:
    p[0x4C - 0x36] = 0x40                    # agility, packed: 0x40 = 64, so digit 8 passes
    #                                       # and digit 9 (72) does not. cmd_R's gate.
    p[0x4B - 0x36] = 0x40                    # strength, for cmd_W next door
    for i in range(1, 10):
        if i == 7:
            continue                         # leave one unowned so the NOT OWNED branch is
        p[0x76 + i - 0x36] = 1               # reachable in a scripted run (7-LI)
    p[0xE3 - 0x36] = 1                       # items_held[13] = STRANGE COIN, which is what
    #                                       # NEGATE TIME spends. DS:E3 is inside items_held;
    #                                       # it is not a separate counter (see commands.c).
    with open(os.path.join(save, "PLAYER"), "wb") as f:
        f.write(bytes(p))
    return 0


if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("usage: cp6_commerce_seed.py DIR CASE", file=sys.stderr)
        raise SystemExit(2)
    raise SystemExit(main(sys.argv[1], sys.argv[2]))
