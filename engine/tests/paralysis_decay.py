#!/usr/bin/env python3
"""
paralysis_decay.py — CP5 gate: a paralyzed player who keeps pressing directions must recover.

This is the bug the owner found by *playing*, not by reading: legs paralysis stranded the
character forever on the open world. Two separate engine mistakes caused it, and the second was
hidden by the first.

1. A bogus site gate. `overworld.c` wrapped the counter decrement in `if (sector_second != 0)`,
   sourced from asm/0C1F's header claiming the tick ran only inside a site. That is false: the
   branch jumps OVER the world-map block and LANDS ON the tick, so both arms reach it.
2. With the gate removed, the tick still did not run on a refused step, because the engine's
   reject path `continue`d before the turn. So a paralyzed player who could not move never
   advanced anything, and nothing decayed. The fix is `status_tick()` on the paralysis reject.

Why this is a gate now. CP5 C3b tried to assert legs decay by counting refusals against a
Daemon, and it was run against a build with the tick deleted entirely — and it still PASSED,
because a successful west step walks the player away from the Daemon and neither build reaches a
terminal state. A gate that cannot fail is worse than no gate, so the assertion was removed and
the gap named. The rig that closes it is not new in this project: CP5 C3d already does exactly
this for **arm** paralysis on the attack path (`--dump-ds`, patch, `--load-ds`), and that gate
also fixed a stranding of its own — the engine had `if (paral_arms == 0) creature_turn(...)`,
which made arm paralysis permanent for a player who kept trying to swing. What C3e adds is the
legs path on the open world, which was the half C3b could not gate.

So: capture the DS mirror with --dump-ds, write DS:26B = 15 into it, resume with --load-ds, and
press LEFT. No monster is involved, so there is nothing to walk away from and nothing random.
Two runs, because each proves a different half:

* three presses -> the paralysis applies, the word prints, the counter gives up exactly three,
  and the player has not moved;
* twenty presses -> the counter reaches zero, and the five presses left after the fifteen
  refusals land as real steps.

The assertions read the DS state, not the screen text, for a reason: --dump-each prints a frame
only when the screen changes, so fifteen identical refusals are not fifteen lines of output and
a word count measures the renderer rather than the rule.

Not modelled, deliberately: the creature sweep is NOT run on a paralysis reject. The byte chain
that puts the sweep on a refused step runs through asm/0A02, which is the TERRAIN reject; the
paralysis path prints a different string and its route to asm/0A33_cmd_done has never been
traced. Monsters acting while the player is pinned is a turn-semantics question that wants a
capture, not a constant to tweak.
"""
import os
import shutil
import subprocess
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import u2_gate as G

PARAL_LEGS_OFF = 0x26B
PARALYSIS = 15          # the corpus saw up to 15 in one castle fight
SHORT = 3               # fewer presses than the counter
LONG = 20               # more

fails = []


def check(cond, msg):
    print(("  ok    " if cond else "  FAIL  ") + msg)
    if not cond:
        fails.append(msg)


def baseline(work):
    """A DS mirror from a real run, so every field in the checkpoint is self-consistent."""
    base = os.path.join(work, "base.ds")
    open(os.path.join(work, "empty.keys"), "w").write("")
    subprocess.run([G.ENGINE, "--headless", "--play-map", "--cleanroom",
                    "--data-dir", os.path.join(work, "content"),
                    "--save-dir", os.path.join(work, "save"),
                    "--script", os.path.join(work, "empty.keys"),
                    "--dump-ds", base],
                   stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                   stderr=subprocess.DEVNULL, check=False)
    ds = bytearray.fromhex(open(base).read().strip())
    ds[PARAL_LEGS_OFF] = PARALYSIS
    path = os.path.join(work, "paralyzed.ds")
    open(path, "w").write(bytes(ds).hex())
    return ds, path


def press(work, ckpt, n):
    kp = os.path.join(work, "k%d" % n)
    with open(kp, "w") as f:
        f.write((G.KEYS["LEFT"] + "\n") * n)
    return subprocess.run(
        [G.ENGINE, "--headless", "--play-map", "--cleanroom",
         "--data-dir", os.path.join(work, "content"),
         "--save-dir", os.path.join(work, "save"),
         "--script", kp, "--load-ds", ckpt, "--dump-state"],
        check=False, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True).stdout


def main():
    print("paralysis_decay: legs paralysis must expire on the open world (asm/0C33)")

    # --- run A: the paralysis applies, and each refused step gives the counter back ---------
    work = tempfile.mkdtemp(prefix="u2-paralysis-a-")
    try:
        G.seed(work)                       # sector 00, all grass, creature parked far away
        ds, ckpt = baseline(work)
        check(len(ds) == 0x280, "DS mirror is 0x280 bytes (%d)" % len(ds))
        out = press(work, ckpt, SHORT)
        st = G.state_from_text(out)
        check(st is not None, "the short run produced a state dump")
        if st is not None:
            legs = G.raw(st, "paralysis")[1]
            check(legs == PARALYSIS - SHORT,
                  "each refused step ticked the counter (%d left after %d presses, want %d)"
                  % (legs, SHORT, PARALYSIS - SHORT))
            check(G.pos(st) == G.ENTRY,
                  "the player did not move while paralyzed (at %s)" % (G.pos(st),))
        check("--PARALIZED!" in out, "the refusal prints --PARALIZED! (asm/2520's word)")
    finally:
        shutil.rmtree(work, ignore_errors=True)

    # --- run B: keep pressing, and the paralysis expires ------------------------------------
    work = tempfile.mkdtemp(prefix="u2-paralysis-b-")
    try:
        G.seed(work)
        _, ckpt = baseline(work)
        out = press(work, ckpt, LONG)
        st = G.state_from_text(out)
        check(st is not None, "the long run produced a state dump")
        if st is not None:
            legs = G.raw(st, "paralysis")[1]
            x, y = G.pos(st)
            check(legs == 0,
                  "DS:26B reached 0 under repeated refused steps (still %d means the reject "
                  "path does not tick — the stranding bug)" % legs)
            check(x == (G.ENTRY[0] - (LONG - PARALYSIS)) % 64,
                  "the %d presses after the counter cleared landed as steps (x=%d, want %d)"
                  % (LONG - PARALYSIS, x, (G.ENTRY[0] - (LONG - PARALYSIS)) % 64))
    finally:
        shutil.rmtree(work, ignore_errors=True)

    print("PARALYSIS DECAY: %s" % ("FAIL (%d)" % len(fails) if fails else "PASS"))
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main())
