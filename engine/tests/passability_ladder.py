#!/usr/bin/env python3
"""
passability_ladder.py — CP5 gate for the on-foot passability ladder.

Why this is a gate and not a unit test: the thing under test is a verdict the engine reaches by
walking, and the failure mode it guards against is a *shape* error — someone replacing the ladder
with a per-tile table again, which is what caused every passability regression this project has had
(docs/passability-findings.md F14). A unit test on the C function would pass for a table that
happened to agree on the rows someone thought of. This drives the real engine and checks whether the
player actually moved.

Method, one fresh seed per tile: put the candidate byte in the cell directly east of the entry,
press RIGHT once, and read the position back out of the turn dump. Moved means accepted. A fresh
save dir every time is not tidiness — the engine rewrites the save in place, and a reused dir was
already responsible for one wrong count in this session.

The expected column is the ladder's verdict, cross-checked against the seven live measurements in
F14's agreement table. Water and mountain are the two named rejections; the eight named
acceptances include the four vehicle tiles, which the old table blocked and which is the whole
reason this was rewritten.
"""
import json
import os
import shutil
import subprocess
import sys

# (map byte, expected accept?, what it is)
CASES = [
    (0x00, False, "open water — 22 live rejects (F11)"),
    (0x04, True,  "shallows — re-proven live, sector 10"),
    (0x08, True,  "grass — walked, F11"),
    (0x0C, True,  "forest — five steps, F11"),
    (0x10, False, "mountain — blocked at (11,20), F11"),
    (0x28, True,  "art 0x0A monument — below the 0x16 threshold"),
    (0x2C, False, "art 0x0B doorway — first byte at/above the threshold"),
    (0x44, True,  "horse tile — named accept, was blocked by the old table"),
    (0x48, True,  "ship tile — named accept, was blocked by the old table"),
    (0x4C, True,  "PLANE tile — named accept, was blocked by the old table"),
    (0x50, True,  "rocket tile — named accept, was blocked by the old table"),
    (0x5C, True,  "force field — g29-field, six crossings"),
    (0x70, True,  "town paving — owner, standing in town"),
    (0x78, False, "building wall art 0x1E — owner-reported blocker"),
    (0x80, False, "letter A, first of the A-Z signs"),
    (0xA0, False, "closed door — asm/433A accepts only 0xA0 as a door"),
]

ENGINE = os.environ.get("U2_BIN", "./u2")
SEED = "tests/cp5_fight_seed.py"


def run_case(work, tile):
    if os.path.isdir(work):
        shutil.rmtree(work)
    subprocess.run([sys.executable, SEED, work], check=True,
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

    # The seeded monx00 spawns its one creature at (3,0) and the spawn-cell clear legitimately
    # writes 0x70 over it, which would silently replace the tile under test. Move the creature.
    mp = os.path.join(work, "content", "mapx00")
    d = bytearray(open(mp, "rb").read())
    d[0 * 64 + 3] = tile
    open(mp, "wb").write(bytes(d))
    fp = os.path.join(work, "content", "monx00")
    m = bytearray(open(fp, "rb").read())
    m[0] = 30
    m[32] = 30
    open(fp, "wb").write(bytes(m))

    keys = os.path.join(work, "k")
    open(keys, "w").write("0xf3\n")          # U2_KEY_RIGHT, from the entry at (2,0)
    dbg = os.path.join(work, "dbg")
    subprocess.run([ENGINE, "--headless", "--play-map", "--cleanroom",
                    "--data-dir", os.path.join(work, "content"),
                    "--save-dir", os.path.join(work, "save"),
                    "--script", keys, "--debug", "cli", "--debug-path", dbg,
                    "--debug-limit", "0"],
                   check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

    dumps = sorted(subprocess.run(["find", dbg, "-name", "turn-*.json"],
                                   capture_output=True, text=True).stdout.split())
    if not dumps:
        return None
    with open(dumps[-1]) as f:
        return json.load(f)["state"]["raw"]["pos"].strip()


def main():
    fails = 0
    for tile, want, why in CASES:
        pos = run_case("/var/tmp/u2-cp5-ladder-%02x" % tile, tile)
        moved = (pos == "03 00")
        ok = (moved == want)
        if not ok:
            fails += 1
        print("  %s  map %#04x -> %-8s %s (%s)" %
              ("PASS" if ok else "FAIL", tile, pos or "no dump",
               "moved" if moved else "refused", why))
    if fails:
        print("  FAIL  %d of %d passability ladder cases wrong" % (fails, len(CASES)))
        return 1
    print("  PASS  passability ladder: %d/%d tiles match asm/2423's verdicts" %
          (len(CASES), len(CASES)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
