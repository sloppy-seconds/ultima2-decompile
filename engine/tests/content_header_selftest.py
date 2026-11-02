#!/usr/bin/env python3
"""Controls for the content-header drift gate (`make -C engine content-check`).

A gate that cannot go red is worse than a tool that lies, and this gate guards
the one file whose silent failure mode is a game that prints nothing: the asm
fallback resolves 181 of 220 strings and blanks the other 38, so a header that
fell back would ship a blank character-creation screen while every text
assertion passed vacuously.

Each control below must make the gate go red in the place it enforces. A
control that cannot find its pattern is itself a failure, not a skip: that is
how a selftest ends up checking nothing.

Run: python3 engine/tests/content_header_selftest.py
"""
import os
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ENGINE = os.path.abspath(os.path.join(HERE, ".."))
REPO = os.path.abspath(os.path.join(ENGINE, ".."))
GEN = os.path.join(ENGINE, "content", "gen_content.h")
EXTRACTOR = os.path.join(ENGINE, "tools", "extract", "extractor.py")

results = []


def check(name, ok, detail=""):
    results.append(ok)
    print(f"  [{'ok ' if ok else 'BAD'}]  {name}{': ' + detail if detail else ''}")


def verify(path):
    return subprocess.run([sys.executable, EXTRACTOR, "--source", "asm",
                           "--verify", "-o", path],
                          cwd=ENGINE, capture_output=True, text=True)


def mutated(old, new, workdir):
    """Copy the committed header with one literal changed. Asserts the pattern
    is present, because a no-op mutation would make the control pass by doing
    nothing."""
    base = open(GEN, encoding="utf-8").read()
    if old not in base:
        return None
    p = os.path.join(workdir, "mutant.h")
    with open(p, "w", encoding="utf-8") as f:
        f.write(base.replace(old, new, 1))
    return p


def main():
    if not os.path.exists(GEN):
        print(f"missing {GEN} — it is committed content, not build output")
        return 1
    base = open(GEN, encoding="utf-8").read()

    with tempfile.TemporaryDirectory() as td:
        print("controls that must each turn the gate red:")
        for name, old, new in [
            ("wrong text",       '#define U2_S_TITLE_REVENGE "REVENGE"',
                                 '#define U2_S_TITLE_REVENGE "WRONG"'),
            ("blanked string",   '#define U2_S_TITLE_REVENGE "REVENGE"',
                                 '#define U2_S_TITLE_REVENGE ""'),
            ("shortened prefix", '#define U2_S_READY_WEAPON_MENU "READY WEAPON:',
                                 '#define U2_S_READY_WEAPON_MENU "READY WEAPEN:'),
        ]:
            p = mutated(old, new, td)
            if p is None:
                check(name, False, "pattern not found — the control tests nothing")
                continue
            r = verify(p)
            check(name, r.returncode != 0,
                  "red" if r.returncode else "GREEN — the gate missed it")

        # A symbol asm resolves but the committed header omits entirely.
        p = os.path.join(td, "missing.h")
        kept = [ln for ln in base.splitlines()
                if not ln.startswith("#define U2_S_TITLE_REVENGE")]
        if len(kept) == len(base.splitlines()):
            check("missing symbol", False, "pattern not found — the control tests nothing")
        else:
            open(p, "w", encoding="utf-8").write("\n".join(kept) + "\n")
            r = verify(p)
            check("missing symbol", r.returncode != 0,
                  "red" if r.returncode else "GREEN — the gate missed it")

        # The downgrade the whole arrangement exists to prevent: the fallback
        # header written over the committed one. Refused by the extractor, not
        # by the Makefile, so it holds however the tool is invoked.
        r = subprocess.run([sys.executable, EXTRACTOR, "--source", "asm",
                            "-o", GEN],
                           cwd=ENGINE, capture_output=True, text=True)
        refused = r.returncode != 0 and "refusing to overwrite" in (r.stdout + r.stderr)
        check("fallback downgrade refused", refused,
              "refused" if refused else f"WROTE OVER IT (exit {r.returncode})")

    r = verify(GEN)
    check("committed header (must be green)", r.returncode == 0,
          (r.stdout + r.stderr).strip().splitlines()[-1] if r.returncode else "green")

    bad = results.count(False)
    print(f"CONTENT HEADER SELFTEST: {'PASS' if bad == 0 else 'FAIL'} "
          f"({len(results) - bad}/{len(results)} controls behaved)")
    return 0 if bad == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
