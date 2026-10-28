#!/usr/bin/env python3
"""u2_gate.py — shared harness for the vehicle gates.

Everything here is the boring half of passability_ladder.py, lifted so the three
vehicle gates (board, food, flight) do not each re-invent it and drift. The rules
that made those tests wrong before are the rules this encodes:

  * a FRESH seed dir per case. The engine rewrites the save in place, and a reused
    dir produced a wrong turn count that looked like a real result (handoff trap 4);
  * the engine-authored filler only. cp5_fight_seed.py writes mapx/monx/PLAYER from
    scratch, so a gate never touches the player's own game files;
  * read the state out of the turn dumps, never out of the exit code. A run that
    refused to move and a run that crashed both exit 0.

The seed's entry point is (2,0) and the map is all grass, so a case places its
interesting byte at (2,0) for "the tile you are standing on" and at (3,0) for
"the tile to the east", which is the one a single RIGHT arrow probes.
"""
import json
import os
import shutil
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ENGINE_DIR = os.path.abspath(os.path.join(HERE, ".."))
ENGINE = os.environ.get("U2_BIN", os.path.join(ENGINE_DIR, "u2"))
SEED = os.path.join(ENGINE_DIR, "tests", "cp5_fight_seed.py")

# The seed's spawn cell, and the cell one step east of it.
ENTRY = (2, 0)
EAST = (3, 0)

# DS:13 travel modes and the tiles that produce them (engine/src/game/overworld.h).
MODE_FOOT, MODE_HORSE, MODE_SHIP, MODE_PLANE, MODE_ROCKET = 0x78, 0x22, 0x24, 0x26, 0x28
TILE_HORSE, TILE_SHIP, TILE_PLANE, TILE_ROCKET = 0x44, 0x48, 0x4C, 0x50

# items_held is DS:0xD6..0xE5 and the save record starts at DS:0x36, so slot n is
# byte 0xA0+n of the PLAYER file. The five vehicle gates, by the names
# docs/spice86-live-findings.md § 11 gives those slots.
ITEM_ANKH, ITEM_SKULL_KEY = 7, 9
ITEM_BRASS_BUTTON, ITEM_BLUE_TASSLE, ITEM_TRI_LITHIUM = 11, 12, 15

# Key tokens the script backend understands, by name rather than by magic byte:
# 0xF0..0xF3 are the arrows, and WAIT is one poll that finds no key.
KEYS = {
    "UP": "0xf0", "DOWN": "0xf1", "LEFT": "0xf2", "RIGHT": "0xf3",
    "WAIT": "WAIT", "SPACE": "SP",
}


def seed(work, tiles=None, items=None, monx=None):
    """Create a fresh seed dir.

    tiles:  {(x, y): byte} written into mapx00
    items:  {slot: count} written into the PLAYER record's items_held
    monx:   None leaves the seeded creature at (3,0); a (x, y) tuple moves it, and
            the default for every case is to park it far away, because a creature
            standing on the cell under test blocks the step for a reason that has
            nothing to do with the rule being tested.
    """
    if os.path.isdir(work):
        shutil.rmtree(work)
    subprocess.run([sys.executable, SEED, work], check=True,
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

    mp = os.path.join(work, "content", "mapx00")
    d = bytearray(open(mp, "rb").read())
    for (x, y), v in (tiles or {}).items():
        d[y * 64 + x] = v
    open(mp, "wb").write(bytes(d))

    fp = os.path.join(work, "content", "monx00")
    m = bytearray(open(fp, "rb").read())
    mx, my = monx if monx else (30, 30)
    m[0], m[32] = mx, my
    open(fp, "wb").write(bytes(m))

    if items:
        pp = os.path.join(work, "save", "PLAYER")
        p = bytearray(open(pp, "rb").read())
        for slot, n in items.items():
            p[0xA0 + slot] = n
        open(pp, "wb").write(bytes(p))

    return work


def pos(dump):
    p = dump["state"]["pos"]
    return (p["x"], p["y"])


def raw(dump, field):
    """A raw DS field as a byte list. `stamp` is one byte, `food` is three."""
    return [int(h, 16) for h in dump["state"]["raw"][field].split()]


def food(dump):
    """The 3-byte packed-decimal food triple DS:53/54/55 as the number it encodes.

    The status band prints only DS:53/54, which is why a 19-charge is invisible on
    screen for ten steps; the raw dump carries all three bytes and the delta is only
    readable there.
    """
    digits = "".join("%02d" % ((b >> 4) * 10 + (b & 0xF)) for b in raw(dump, "food"))
    return int(digits)


def stamp(dump):
    return raw(dump, "stamp")[0]


def map_byte(work, x, y):
    """Read a cell back out of the sector file after a save: what the world looks like to
    the next player who loads this sector. Only meaningful after a Q, because the engine
    stores a sector when it is dirty and nothing else writes the file."""
    return open(os.path.join(work, "content", "mapx00"), "rb").read()[y * 64 + x]


def run_stdout(work, keys, name="case"):
    """Run the engine and return its stdout as text.

    The headless renderer prints the vram grid, so this is how a gate reads what the
    player would have seen. Same seed, same fresh dir rules as run().
    """
    keys_path = os.path.join(work, "k-%s" % name)
    with open(keys_path, "w") as f:
        for k in keys:
            f.write(KEYS.get(k, k) + "\n")
    r = subprocess.run([ENGINE, "--headless", "--play-map", "--cleanroom",
                        "--data-dir", os.path.join(work, "content"),
                        "--save-dir", os.path.join(work, "save"),
                        "--script", keys_path, "--dump-state"],
                       check=False, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                       text=True)
    return r.stdout


def flatten(text):
    """The ASCII screen as one line, so a phrase that wrapped across two rows still matches.

    The box drawing and the padding are dropped; runs of whitespace collapse to one space.
    A gate asserting on a whole sentence would still be brittle, because a row break can
    split a word, so assert on short distinctive words instead.
    """
    return " ".join(text.replace("|", " ").replace("+", " ").split())


def state_from_text(text):
    """The final DS state out of a --dump-state run.

    This is the read path for anything a command changes without taking a world turn, and
    BOARD is exactly that: the turn dumps are written once per turn, and asm/2FAD's arms
    end at cmd_done without a creature sweep, so a run of B alone writes no turn file at
    all. A gate that only knows how to read turn dumps would have to press a direction
    after every command just to observe the command's effect — and would then be measuring
    the step as well.

    It is also the reason this harness does not read sector files back off disk: that path
    goes through the save subsystem, and the save subsystem has a defect of its own
    (docs/phase4-state.md, OPEN DEFECT). Observe the value, not a round trip through the
    thing under test.
    """
    for line in reversed(text.strip().splitlines()):
        line = line.strip()
        if line.startswith("{") and line.endswith("}"):
            return json.loads(line)
    return None


def state(work, keys, name="state"):
    return state_from_text(run_stdout(work, keys, name))
