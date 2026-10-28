#!/usr/bin/env python3
"""
vehicle_dismount.py — CP5 gate for X-IT (asm/44D4), the dismount that BOARD's twin.

BOARD consumes the vehicle tile and sets DS:13; nothing in the engine used to put either back.
asm/44D4 is that other half, and the pair is symmetric down to the arithmetic: BOARD reads the
tile shifted right one, X-IT writes `2 * [DS:13]` back through the same cell pointer, so the
tile is not destroyed by boarding — it is carried. Then DS:13 becomes `0x78 + 2*[DS:47]`, which
is the class-dependent on-foot stamp, not the constant 0x78 every capture happens to show
(because every capture so far was a fighter).

The flow, from the bytes:

    "X-IT" ; [DS:13] >= 0x78            -> " WHAT?"      (on foot: nothing to destroy)
             [DS:14] == 0x04 (grass)    -> allowed
             [DS:14] == 0x00 and ship   -> allowed       (drop the ship on water)
             anything else              -> "-NOT HERE!"
             write 2*[DS:13] into the cell ; [DS:13] = 0x78 + 2*pclass

What this gate covers end to end, and what it does not:

* on foot -> " WHAT?", mode unchanged, tile untouched;
* horse on grass -> tile back to 0x44, mode back to 0x78;
* ship on water -> tile back to 0x48, mode back to 0x78 — the ship's own clause, and the only
  way to reach it, because boarding a land vehicle leaves grass under the player;
* the "-NOT HERE!" arm is NOT reachable from a scripted foot start: it needs a non-ship vehicle
  standing on water, which in play means a plane flown over the sea, and the flight loop is
  ungated pending G39/G43. That arm is covered at unit level in tests/site_check.c instead,
  against the same rule function this gate drives end to end.

The tile is read back from the sector file after a Q. That is legal here and only here: after a
successful dismount the player is on foot, so the save's own on-foot guard passes.
"""
import os
import shutil
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import u2_gate as G

fails = []

GRASS = 0x08   # what the seed's map is made of, and what a land vehicle leaves behind


def check(cond, msg):
    print(("  ok    " if cond else "  FAIL  ") + msg)
    if not cond:
        fails.append(msg)


def run_case(label, tiles, items, keys, want_stamp, want_tile, want_word):
    work = tempfile.mkdtemp(prefix="u2-dismount-")
    try:
        G.seed(work, tiles=tiles, items=items)
        # --enhanced for the save, and it is not cosmetic: while the player is still mounted the
        # original's own on-foot guard refuses Q, so a faithful save would leave the file at its
        # seeded bytes and the tile assertion below would pass without the dismount ever having
        # happened. The assertion is about the tile X-IT writes, not about the save path.
        text = G.run_stdout(work, keys + ["Q"], name=label, extra=["--enhanced"])
        flat = G.flatten(text)
        d = G.state_from_text(text)
        stamp = G.stamp(d) if d else None
        check(stamp == want_stamp,
              "%s: DS:13 = %s, want 0x%02X" % (label, "none" if stamp is None
                                               else "0x%02X" % stamp, want_stamp))
        tile = G.map_byte(work, *G.ENTRY)
        check(tile == want_tile, "%s: cell left as 0x%02X, want 0x%02X" % (label, tile, want_tile))
        if want_word:
            check(want_word in flat, "%s: screen shows %r" % (label, want_word))
    finally:
        shutil.rmtree(work, ignore_errors=True)


def main():
    print("vehicle_dismount: X-IT returns the tile and the foot stamp (asm/44D4)")

    # 1. On foot: nothing to destroy. Mode and tile must not move at all.
    run_case("on-foot", {}, {}, ["X"], G.MODE_FOOT, GRASS, "WHAT?")

    # 2. Horse on grass: the tile comes back as 2*0x22 and the mode as the foot stamp.
    run_case("horse", {G.ENTRY: G.TILE_HORSE}, {}, ["B", "X"],
             G.MODE_FOOT, G.TILE_HORSE, "X-IT")

    # 3. Ship on water: boarding the frigate leaves water under the player, which is the only
    #    way the ship's own clause can ever be reached. Needs the blue tassle.
    run_case("ship", {G.ENTRY: G.TILE_SHIP}, {G.ITEM_BLUE_TASSLE: 1}, ["B", "X"],
             G.MODE_FOOT, G.TILE_SHIP, "X-IT")

    # 4. Plane needs the skull key; dismount on grass returns the plane tile.
    run_case("plane", {G.ENTRY: G.TILE_PLANE}, {G.ITEM_SKULL_KEY: 1}, ["B", "X"],
             G.MODE_FOOT, G.TILE_PLANE, "X-IT")

    print("VEHICLE DISMOUNT: %s" % ("FAIL (%d)" % len(fails) if fails else "PASS"))
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main())
