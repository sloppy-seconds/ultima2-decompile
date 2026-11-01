#!/usr/bin/env python3
"""
wound_flash.py — CP5 gate E2: the wound flash fires on the victim's cell, both directions.

Evidence basis: captures/spice86/wound-flash-20261102 (owner playtest; the ring was
caught in video memory at the player's cell on each of three orc hits, and at the
ORC's cell — five scanlines above — on the turn the player's attack landed). The
engine reproduces it as XOR-on, tone, XOR-off (asm/5255 -> asm/4C1E twice with
asm/5EF2 between), and the flash leaves the frame bit-identical, so the observable
this gate reads is the diag counter `flashes` in the turn dumps, correlated turn by
turn against the HP pair.

Arms:
  wound    seeded creature adjacent, PASS until it lands a hit. Every wounded turn
           (HP pair changed) must raise `flashes` by exactly one — the engine pools
           a turn's melee into one flash — and at least one turn must wound, or the
           arm proves nothing.
  attack   seeded creature adjacent, 32 swings rotating through all four aims.
           Wound flashes always coincide with an HP change; attack flashes never
           do, so flashes > wounded-turns can only mean the ring fired on the
           attacked creature's cell — the both-directions half of the capture. A
           gate that only checked "flashes > 0" would pass on the orc's counter-hits
           alone — that is the naive version this shape refuses to be.
  control  creature parked at (30,30), PASS x3: no wounds, no swings, flashes == 0.
           Without this the counter could be a per-turn tick and the gate could
           never go red.

Fresh seed dir per arm (u2_gate rule: the engine rewrites the save in place).
"""
import json
import os
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import u2_gate as G

ENGINE = os.environ.get("U2_BIN", os.path.join(G.ENGINE_DIR, "u2"))


def run_dumps(work, keys):
    """Run with the debug turn-dumper and return the dumps in order."""
    dbg = os.path.join(work, "dbg")
    keys_path = os.path.join(work, "k")
    with open(keys_path, "w") as f:
        for k in keys:
            f.write(G.KEYS.get(k, k) + "\n")
    subprocess.run([ENGINE, "--headless", "--play-map", "--cleanroom",
                    "--data-dir", os.path.join(work, "content"),
                    "--save-dir", os.path.join(work, "save"),
                    "--script", keys_path, "--debug", "cli", "--debug-path", dbg,
                    "--debug-limit", "0"],
                   check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    paths = sorted(subprocess.run(["find", dbg, "-name", "turn-*.json"],
                                  capture_output=True, text=True).stdout.split())
    return [json.load(open(p)) for p in paths]


def hp(d):
    return G.raw(d, "hp")


def flashes(d):
    return d["state"].get("flashes", -1)


def wound_turns(dumps):
    """Turns on which the HP pair changed, i.e. the player was wounded."""
    n = 0
    for a, b in zip(dumps, dumps[1:]):
        if hp(a) != hp(b):
            n += 1
    return n


def main():
    fails = 0

    def check(label, ok, detail):
        nonlocal fails
        if not ok:
            fails += 1
        print("  %s  %s — %s" % ("PASS" if ok else "FAIL", label, detail))

    # wound: PASS turns next to the creature; every wound is one flash.
    work = G.seed("/var/tmp/u2-wflash-wound")
    dumps = run_dumps(work, ["SPACE"] * 6)
    wt = wound_turns(dumps)
    total = flashes(dumps[-1]) if dumps else -1
    check("wound", dumps and wt >= 1 and total == wt,
          "%d wounded turns, %d flashes (want equal, >=1)" % (wt, total))

    # attack: an attack flash is a flash on a turn the player was NOT wounded —
    # wound flashes always coincide with an HP change (the pooled blow is >= 1),
    # attack flashes never do. So flashes minus wounded-turns counts the landed
    # swings, and >= 1 proves the ring fired on the attacked creature's cell.
    # The swings rotate through all four aims because the creature moves between
    # turns (a fixed aim attacks whatever cell is east NOW, often empty after a
    # tick), and the wander spawner keeps the field alive, so no kill is asserted.
    # The seed's agility byte makes a swing that finds a creature certain to land.
    work = G.seed("/var/tmp/u2-wflash-attack")
    dumps = run_dumps(work, ["A", "UP", "A", "RIGHT", "A", "DOWN", "A", "LEFT"] * 8)
    wt = wound_turns(dumps)
    total = flashes(dumps[-1]) if dumps else -1
    check("attack", dumps and total >= wt + 1,
          "%d wounded turns, %d flashes (want >= wounds+1: the extra is the "
          "attacked creature's ring)" % (wt, total))

    # control: nobody near, nothing to flash.
    work = G.seed("/var/tmp/u2-wflash-control", monx=(30, 30))
    dumps = run_dumps(work, ["SPACE"] * 3)
    total = flashes(dumps[-1]) if dumps else -1
    check("control", dumps and total == 0 and wound_turns(dumps) == 0,
          "%d flashes, %d wounded turns on a quiet map (want 0, 0)"
          % (total, wound_turns(dumps)))

    if fails:
        print("  FAIL  %d of 3 wound-flash arms wrong" % fails)
        return 1
    print("  PASS  wound flash: one per wounded turn at the player's cell, one on the "
          "attacked creature's cell, none when nobody is hit")
    return 0


if __name__ == "__main__":
    sys.exit(main())
