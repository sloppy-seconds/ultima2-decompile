#!/usr/bin/env python3
"""CP6 gate: a consumed TRANSACT- aim must produce a reply.

Owner report 2026-10-29: in Port Boniface the two NPCs standing south of the shops answered
nothing when TRANSACT was aimed at them, and aiming through one of them at a vendor looked
like the game had frozen. Three `return U2_TRANSACT_NO_DEALER` paths in commerce.c printed
nothing at all -- the tlkx talking branch and two shop gaps. AGENTS.md forbids precisely
this: a turn consumed, no message, and no cited byte justifying the silence.

Why this is a separate checker instead of a grep in run_cp6.sh: the obvious assertion --
"did anything get printed after TRANSACT-" -- is INERT. The direction word is always
printed, so it passes on the very bug it is meant to catch. I wrote that version first and
it went green with the fix removed, which is the failure mode this project has now been
bitten by repeatedly enough to be a house hazard.

The non-inert question is what was said AFTER the direction word. The status band and the
next prompt always follow, so those are excluded by name and whatever remains is the reply.
If nothing remains, the gap was silent.

Usage: cp6_silence_check.py <engine-binary> <data-dir> <work-dir>
Exit 0 = the aim was answered. Exit 1 = silent gap. Exit 2 = the case is not testing
what it claims (no aim consumed at all), which is never allowed to read as a pass.
"""
import os
import re
import shutil
import subprocess
import sys

UP = b"\xf0"          # U2_KEY_UP, the byte the engine's own input layer uses
X, Y = 51, 46         # Port Boniface: an NPC stands in the shop's sign cell here

# Printed on every turn regardless of what the aim did. Not a reply.
NOISE = re.compile(r"^(H\.P\.=|FOOD=|EXP\.=|GOLD=|CMD: ?|TRANSACT-|NORTH|SOUTH|EAST|WEST)")


def main() -> int:
    if len(sys.argv) != 4:
        print(__doc__)
        return 2
    engine, data, work = (os.path.abspath(p) for p in sys.argv[1:4])
    root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    editor = os.path.join(root, "tools", "u2_edit.py")
    for need in (os.path.join(data, "mapx31"), os.path.join(data, "monx31")):
        if not os.path.isfile(need):
            print(f"silence-check: SKIP (missing {need})")
            return 2

    save = os.path.join(work, "save")
    shutil.rmtree(work, ignore_errors=True)
    os.makedirs(save)
    shutil.copy(os.path.join(data, "player"), os.path.join(save, "PLAYER"))
    for args in (["set", "sector", "31"], ["setpos", str(X), str(Y)]):
        subprocess.run([sys.executable, editor, args[0],
                        os.path.join(save, "PLAYER"), *args[1:]],
                       capture_output=True, check=False)
    with open(os.path.join(work, "k.keys"), "wb") as f:
        f.write(b"T\n" + UP + b"\n")

    try:
        r = subprocess.run([engine, "--headless", "--play-map", "--data-dir", data,
                            "--save-dir", save, "--script", os.path.join(work, "k.keys"),
                            "--trace"], capture_output=True, text=True, timeout=60)
    except subprocess.TimeoutExpired:
        print("silence-check: FAIL (the engine hung instead of answering)")
        return 1

    out = (r.stdout or "") + (r.stderr or "")
    texts = [t for t in re.findall(r"str_out .*?text=(.*)", out) if t.strip()]
    if not any(t.startswith("TRANSACT-") for t in texts):
        print("silence-check: FAIL (no TRANSACT- produced; the case proves nothing)")
        return 2

    # Everything after the direction word, minus the band and the prompt.
    try:
        i = next(n for n, t in enumerate(texts)
                 if t.strip() in ("NORTH", "SOUTH", "EAST", "WEST"))
    except StopIteration:
        print("silence-check: FAIL (the aim was never consumed)")
        return 1
    reply = [t for t in texts[i + 1:] if not NOISE.match(t.strip())]

    if reply:
        print(f"silence-check: ok -- the aim was answered: {reply[0]!r}")
        return 0
    print("silence-check: FAIL -- the aim was consumed and NOTHING was printed (silent gap)")
    return 1


if __name__ == "__main__":
    sys.exit(main())
