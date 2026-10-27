#!/usr/bin/env python3
"""
grid_check.py — is the engine's restamp a faithful reconstruction of the original's grid?

The checkpoint carries DS:00..0x280. The creature grid is at DS:1800 and is NOT in it, so the
engine rebuilds it: clear to terrain, then stamp one cell per live creature slot. That is a claim
about the original's grid, and it has never been tested.

Test: take the original's own grid, subtract the raw mapx terrain, and the leftover cells are
whatever the game had stamped. Compare that set against the set of live creature positions. Any
cell stamped with no creature behind it is a ghost the restamp cannot reproduce - and a ghost
changes the passability gate, which is exactly how identical rolls could move creatures to
different places.
"""
import json
import sys

MAPX = {0x03: "original/mapx03"}


def load_mapx(path):
    with open(path, "rb") as f:
        raw = f.read()
    return raw[:64 * 64]


def cells(grid, terrain):
    """Cells whose grid byte differs from the raw terrain byte."""
    out = set()
    for i in range(64 * 64):
        if grid[i] != terrain[i]:
            out.add((i % 64, i // 64))
    return out


def main(path, sample):
    rec = json.load(open(path))
    turns = rec["turns_data"]
    t = turns[sample]
    grid = bytes.fromhex(t["ds"]["grid"].replace(" ", ""))
    ds = t["ds"]
    # sector is the raw 2-byte little-endian field, e.g. "00 03". Take the low byte.
    sector = int(ds["sector"].split()[-1], 16)
    terrain = load_mapx(MAPX.get(sector, f"original/mapx{sector:02x}"))

    live = set()
    xs = ds["mon_x"].split()
    ys = ds["mon_y"].split()
    ts = ds["mon_type"].split()
    for i in range(32):
        if int(ts[i], 16) != 0:
            live.add((int(xs[i], 16), int(ys[i], 16)))

    stamped = cells(grid, terrain)
    ghosts = stamped - live
    unstamped = live - stamped

    print(f"sector {sector:02x}, sample {sample}")
    print(f"  live creature cells : {len(live)}")
    print(f"  stamped cells       : {len(stamped)}")
    print(f"  GHOSTS (stamped, no creature) : {len(ghosts)}")
    print(f"  UNSTAMPED (creature, not stamped): {len(unstamped)}")
    if ghosts:
        print("  ghost cells:", sorted(ghosts)[:20])
    if unstamped:
        print("  unstamped cells:", sorted(unstamped)[:20])
    verdict = "RESTAMP IS FAITHFUL" if not ghosts and not unstamped else "RESTAMP IS NOT FAITHFUL"
    print(f"  => {verdict}")
    return 0 if not ghosts and not unstamped else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1], int(sys.argv[2]) if len(sys.argv) > 2 else 0))
