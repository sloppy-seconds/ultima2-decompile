#!/usr/bin/env python3
"""
vehicle_board.py — CP5 gate for BOARD (asm/2F6F -> asm/2FAD) and the per-mode food charge.

Two things are under test here, and they are the two the byte evidence is strongest for.

BOARD (W1). asm/2FAD dispatches on [DS:14] — the map byte under the player shifted right
once — and each arm sets DS:13 and writes a ground byte through the cell pointer. The gate
asserts the mode byte, the position (BOARD must NOT move the player, measured in
captures/spice86/ship-port-boniface) and the words on screen. The refusals are asserted
too, and they are not invented: each names the item that gates it, and
spice86-live-findings.md § 11 already puts those words in exactly the slots the gate bytes
are. The tile each arm
leaves behind is listed in the case table but NOT asserted, for the reason in board_case().

Food per mode (W3). asm/253B's dispatch decides the charge: one 19 on foot, two on horse or
plane (asm/2626 subtracts once and then calls the foot tail, which subtracts again), none
aboard the ship, and none in the rocket — the rocket arm at asm/2542 jumps straight to the
reject return and never reaches a drain. The delta is read from the raw food triple, not the
status band: the band prints four digits and hides the low byte, which is why a 19-charge is
invisible on screen for ten steps.

The control that makes this gate able to fail is the foot case: if a refactor of the mode
dispatch ever charges the wrong amount on foot, the case that has always been true goes red.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import u2_gate as G

# (name, tile under the player, items, expected DS:13 after B, the tile that arm writes
#  through the cell pointer [recorded here, NOT asserted — see board_case], a word that
#  must be on screen). The words are short on purpose: the screen is 40 columns and a
#  whole sentence can wrap across two rows.
BOARD_CASES = [
    ("horse",          G.TILE_HORSE,  {},                      G.MODE_HORSE,  0x08, "HORSE"),
    ("ship-refused",   G.TILE_SHIP,   {},                      G.MODE_FOOT,   0x48, "BOARD!"),
    ("ship",           G.TILE_SHIP,   {G.ITEM_BLUE_TASSLE: 1}, G.MODE_SHIP,   0x00, "FRIGATE"),
    ("plane-refused",  G.TILE_PLANE,  {},                      G.MODE_FOOT,   0x4C, "STRANGE"),
    ("plane",          G.TILE_PLANE,  {G.ITEM_SKULL_KEY: 1},   G.MODE_PLANE,  0x08, "PLANE"),
    ("rocket-refused", G.TILE_ROCKET, {},                      G.MODE_FOOT,   0x50, "ANKH!"),
    ("rocket",         G.TILE_ROCKET, {G.ITEM_ANKH: 1},        G.MODE_ROCKET, 0x08, "ROCKET"),
    ("not-a-vehicle",  0x08,          {},                      G.MODE_FOOT,   0x08, "WHAT?"),
]

# (name, tile under the player, items, mode label, expected food delta for ONE step attempt)
FOOD_CASES = [
    ("foot",   0x08,          {},                        "foot",   19),
    ("horse",  G.TILE_HORSE,  {},                        "horse",  38),
    ("plane",  G.TILE_PLANE,  {G.ITEM_SKULL_KEY: 1},     "plane",  38),
    ("ship",   G.TILE_SHIP,   {G.ITEM_BLUE_TASSLE: 1},   "ship",    0),
    ("rocket", G.TILE_ROCKET, {G.ITEM_ANKH: 1},          "rocket",  0),
]


def board_case(name, tile, items, want_mode, want_left, want_word):
    work = G.seed("/var/tmp/u2-veh-board-%s" % name,
                  tiles={G.ENTRY: tile}, items=items)
    text = G.run_stdout(work, ["B"], name="screen")
    d = G.state_from_text(text)
    if d is None:
        return ["no --dump-state output"]
    out = G.flatten(text)

    errs = []
    if G.pos(d) != G.ENTRY:
        errs.append("moved to %s (BOARD must not move the player)" % (G.pos(d),))
    if G.stamp(d) != want_mode:
        errs.append("DS:13 = 0x%02X, want 0x%02X" % (G.stamp(d), want_mode))
    if want_word not in out:
        errs.append("screen has no %r" % want_word)
    # The tile BOARD leaves behind (want_left) is deliberately NOT asserted here, and it is
    # not laziness: asserting it needs a Q, and Q on a dirty sector currently writes the
    # map over the MONX file, because u2_world_store reuses the single w->found_prefix the
    # monster load set last. That is a pre-existing engine defect, reproduced at HEAD with
    # no vehicle code anywhere in the picture (UNLOCK a door, then save), and it is
    # recorded in docs/needs-gameplay.md G35 with its repro. A gate that rides on a save
    # path which corrupts a different file would report green while doing damage.
    # The write itself is still exercised: BOARD picks its arm from the tile under the
    # player, so the mode above only comes out right if that read and the write agree.
    return errs


def food_case(name, tile, items, mode, want_delta):
    """Charge with and without a step, from two runs of the same seed, so the delta is
    the step's alone and not the boarding's."""
    base = G.seed("/var/tmp/u2-veh-food-%s-a" % name, tiles={G.ENTRY: tile}, items=items)
    step = G.seed("/var/tmp/u2-veh-food-%s-b" % name, tiles={G.ENTRY: tile}, items=items)
    board = ["B"] if tile != 0x08 else []
    a = G.state(base, board, name="a")
    b = G.state(step, board + ["RIGHT"], name="b")
    if not a or not b:
        return ["no --dump-state output"]
    got = G.food(a) - G.food(b)
    errs = []
    if got != want_delta:
        errs.append("%s step cost %d, want %d" % (mode, got, want_delta))
    want_mode = {"foot": G.MODE_FOOT, "horse": G.MODE_HORSE, "plane": G.MODE_PLANE,
                 "ship": G.MODE_SHIP, "rocket": G.MODE_ROCKET}[mode]
    if G.stamp(b) != want_mode:
        errs.append("%s: DS:13 = 0x%02X after boarding, want 0x%02X"
                    % (mode, G.stamp(b), want_mode))
    if mode == "rocket" and G.pos(b) != G.ENTRY:
        errs.append("rocket stepped, but asm/2542 rejects every step")
    if mode == "ship" and G.pos(b) != G.ENTRY:
        errs.append("ship stepped onto grass, but asm/2619 accepts water only")
    return errs


def main():
    fails = 0
    for name, tile, items, mode, left, word in BOARD_CASES:
        errs = board_case(name, tile, items, mode, left, word)
        fails += bool(errs)
        print("  %s  BOARD on %-14s -> DS:13 0x%02X, %r%s" %
              ("PASS" if not errs else "FAIL", name, mode, word,
               "" if not errs else " — " + "; ".join(errs)))
    for name, tile, items, mode, delta in FOOD_CASES:
        errs = food_case(name, tile, items, mode, delta)
        fails += bool(errs)
        print("  %s  one step in %-6s costs %2d food%s" %
              ("PASS" if not errs else "FAIL", mode, delta,
               "" if not errs else " — " + "; ".join(errs)))
    if fails:
        print("  FAIL  %d vehicle board/food cases disagree with asm/2FAD and asm/253B" % fails)
        return 1
    print("  PASS  vehicle board + food: %d/%d cases match asm/2FAD and asm/253B" %
          (len(BOARD_CASES) + len(FOOD_CASES), len(BOARD_CASES) + len(FOOD_CASES)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
