#!/usr/bin/env python3
"""
foot_stamp.py — CP5 gate: the on-foot stamp at world open is class-dependent, not 0x78.

asm/080D computes `mov 0x47,%al ; add %al,%al ; clc ; adc $0x78,%al`, i.e. DS:13 = 0x78 + 2*pclass,
and asm/44D4 restores the same expression when X-IT dismounts. The engine used the constant 0x78 at
world open, which is invisible for a Fighter — a Fighter's stamp IS 0x78 — and wrong for the other
three classes. It stayed invisible because every capture and every seeded test character in this
project has been a Fighter.

Closed from the other side on 2026-10-29: a class-2 Wizard loaded into the original read
DS:13 = 0x7A on foot, live, in captures/spice86/shop-window-transport. docs/needs-gameplay.md G41.

Why this is a gate and not just a one-line fix. The fix is trivial and the bug was not: a constant
that is right for the only class anyone tested is exactly the shape of defect this project keeps
finding, and the same expression now lives in three places (world open, dismount, and the original's
two sites). Asserting all four classes at world open is what stops the constant coming back.

The class byte is DS:47, and the save record starts at DS:36, so it is byte 0x11 of the PLAYER file.
"""
import os
import shutil
import subprocess
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import u2_gate as G

CLASS_OFF = 0x11          # DS:47 - 0x36
CLASSES = [(0, "FIGHTER", 0x78), (1, "CLERIC", 0x7A),
           (2, "WIZARD", 0x7C), (3, "THIEF", 0x7E)]

fails = []


def check(cond, msg):
    print(("  ok    " if cond else "  FAIL  ") + msg)
    if not cond:
        fails.append(msg)


def main():
    print("foot_stamp: DS:13 at world open must be 0x78 + 2*pclass (asm/080D)")
    for cls, name, want in CLASSES:
        work = tempfile.mkdtemp(prefix="u2-stamp-")
        try:
            G.seed(work)
            pp = G.record(work)
            p = bytearray(open(pp, "rb").read())
            p[CLASS_OFF] = cls
            open(pp, "wb").write(bytes(p))

            out = G.run_stdout(work, [], "cls%d" % cls)
            st = G.state_from_text(out)
            check(st is not None, "%s run produced a state dump" % name)
            if st is not None:
                got = G.stamp(st)
                check(got == want,
                      "class %d (%s) enters the world with DS:13 = 0x%02x (got 0x%02x)"
                      % (cls, name, want, got))
        finally:
            shutil.rmtree(work, ignore_errors=True)

    print("FOOT STAMP: %s" % ("FAIL (%d)" % len(fails) if fails else "PASS"))
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main())
