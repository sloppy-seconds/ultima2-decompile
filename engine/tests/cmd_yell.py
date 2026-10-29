#!/usr/bin/env python3
"""
cmd_yell.py — CP5 gate: cmd_Y is a freeform line input terminated by Enter, and it changes
nothing but what is on the screen.

asm/4542 prints "YELL WHAT?" and falls into asm/4551..asm/4567, which for a long time read as an
unresolved tail because the Phase 3 cut scattered a complete routine across seven fragments, each
headed "behavior not yet reviewed". Read as one address-ordered stream it is: spin on the key
seam, echo every character, stop on Enter, print the Enter, return to the dispatcher. Nothing in
the range writes memory.

The owner's recollection of the manual is what sent the re-read, and it is also the reason this
gate exists in this shape: the manual says Y lets you type a freeform thing to yell, with Enter.
So the gate asserts the four properties that claim contains, and the third one is the interesting
one.

1. the prompt prints, and what you type comes back on the screen;
2. Enter ends it, and the next key is a command again;
3. **without** Enter the next letter is NOT a command — it is yell text. This is the property the
   2026-10-25 capture stumbled into and mislabelled as "the command loop does not return to the
   prompt": letters typed after Y accumulated on the CMD line and never dispatched, which was the
   feature running correctly and being read as a defect. A gate that only checks 1 and 2 would
   pass a handler that printed the prompt and returned immediately.
4. the yell costs nothing: no turn, so no food, and no state field moves. This is the byte claim
   "no writes in the range" made testable.

Case is asserted too, and deliberately: the echo is UPPER-CASED, because asm/4F4D's key seam
folds a-z to A-Z at asm/4FD3..asm/4FDB (`cmp $0x61 ; jb` / `cmp $0x7a ; ja` / `and $0xdf,%al`)
and its header records that BOTH returns fall into that tail. So no caller in the original ever
saw a lowercase byte, and cmd_Y's echo cannot have printed one.

This expectation was written the other way and the tripwire did its job. The original wording was
"the echo preserves it, because the upper-casing belongs to the key seam and the engine does not
model that engine-wide. If the seam ever grows it, this check goes red on purpose so the decision
gets revisited rather than silently absorbed." It went red on 2026-10-29 when the fold was added
to seam_key_wait, which is the revisit. The fold had been on the poll path only, so shops and
prompts that WAIT (read_yes, read_digit, this loop) received raw lowercase and refused a human
player — while no scripted capture could show it, because tools/spice86_type.py sends the shifted
key. The decision is therefore: the seam models asm/4F4D engine-wide, and callers see uppercase.
"""
import os
import shutil
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import u2_gate as G

fails = []


def check(cond, msg):
    print(("  ok    " if cond else "  FAIL  ") + msg)
    if not cond:
        fails.append(msg)


def main():
    print("cmd_yell: asm/4542 + the echo loop at asm/4551..4567 (freeform input, Enter ends it)")

    # --- 1 + 2: the prompt, the echo, and Enter handing control back -------------------------
    work = tempfile.mkdtemp(prefix="u2-yell-")
    try:
        G.seed(work)
        out = G.run_stdout(work, ["Y", "H", "I", "T", "L", "E", "CR", "LEFT"], "yell")
        flat = G.flatten(out)
        check("HITL" in flat, "what was typed is echoed back (asm/455D char_print_wrap)")

        st = G.state_from_text(out)
        check(st is not None, "the run produced a state dump")
        if st is not None:
            check(G.pos(st) == (G.ENTRY[0] - 1, G.ENTRY[1]),
                  "Enter ended the loop and the next key was a command again (pos=%s)"
                  % (G.pos(st),))

        # --- 4: the yell itself is display-only ---------------------------------------------
        # The prompt is asserted on THIS run, not the one above: the CMD window scrolls, so a
        # command typed after the yell pushes "YELL WHAT?" off the screen and a prompt check on
        # that run would be measuring the renderer rather than the handler.
        base = G.state(work, [], "baseline")
        bare_out = G.run_stdout(work, ["Y", "N", "O", "O", "P", "E", "CR"], "bare")
        check("YELL WHAT?" in G.flatten(bare_out),
              "the prompt prints (asm/4542's inline string)")
        bare = G.state_from_text(bare_out)
        check(base is not None and bare is not None, "both state runs produced dumps")
        if base and bare:
            for field in ("pos", "hp", "food", "gold", "stamp", "items"):
                check(G.raw(bare, field) == G.raw(base, field),
                      "the yell left DS:%s alone (display-only, no writes in the range)" % field)
    finally:
        shutil.rmtree(work, ignore_errors=True)

    # --- 3: without Enter the next letter is yell text, not a command ------------------------
    work = tempfile.mkdtemp(prefix="u2-yell-swallow-")
    try:
        G.seed(work)
        swallowed = G.run_stdout(work, ["Y", "H", "J"], "swallow")
        check("HYPER WHAT?" not in G.flatten(swallowed),
              "J typed inside a yell is echoed, not dispatched — no HYPER WHAT? (the 2026-10-25 "
              "capture's 'never dispatched' observation)")
        check("JUMP" not in G.flatten(swallowed),
              "and a second letter after it is swallowed too")

        # Control for the control: the same letter with no yell in front of it must dispatch,
        # or assertion 3 would be measuring a broken J rather than a working loop.
        out_j = G.run_stdout(work, ["J"], "j-alone")
        check("JUMP" in G.flatten(out_j),
              "control: J on its own does dispatch (prints JUMP...WHEE...), so the swallow "
              "above is the loop's doing and not a broken J")
    finally:
        shutil.rmtree(work, ignore_errors=True)

    # --- case: the seam's upper-casing is not the handler's business -------------------------
    work = tempfile.mkdtemp(prefix="u2-yell-case-")
    try:
        G.seed(work)
        out = G.run_stdout(work, ["Y", "M", "i", "x", "e", "d", "CR"], "case")
        check("MIXED" in G.flatten(out),
              "echo is upper-cased by the seam: asm/4FD3..4FDB folds a-z on both key paths")
    finally:
        shutil.rmtree(work, ignore_errors=True)

    print("CMD YELL: %s" % ("FAIL (%d)" % len(fails) if fails else "PASS"))
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main())
