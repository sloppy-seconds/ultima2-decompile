#!/usr/bin/env python3
"""apple2_index.py — the committed function index for the Apple II 6502 import.

`decompiled/apple2-6502/u2_6502.tsv` is Ghidra's own export and it is gitignored (derived from
copyrighted bytes). This is the curated, committed subset: addresses, segment, span and verdict.
No decompiled code, no game text — the same line `AGENTS.md` draws for `disasm/`.

One honest caveat, because the naive column would have lied: DecompileAll.java reports
`body_bytes` for every function in this import as **1**. The seeded functions are created with
`createFunction` on an image with no disassembly pass behind them, so Ghidra's function *body*
never extends past the entry byte even though the decompiled C is real and multi-instruction.
So this index does not carry body_bytes; it carries `span_bytes` = distance to the next seed,
which is what you can actually use to bound a routine, and it says so in the header.

    python3 tools/apple2_index.py -o disasm/apple2-functions.tsv
    python3 tools/apple2_index.py --check          # diff against the committed file
"""
import argparse
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import apple2_image  # noqa: E402

TSV = "/var/tmp/u2-apple2-6502/u2_6502.tsv"
SEEDS = "disasm/apple2-seeds.txt"

HEADER = """# Apple II 6502 function index. Generated — do not hand-edit.
#   python3 tools/apple2_index.py -o disasm/apple2-functions.tsv
# Source: Ghidra 6502 import of the flat image (tools/apple2_ghidra.sh).
# span_bytes is the distance to the next seed, NOT a Ghidra body size: DecompileAll reports
# body_bytes=1 for every function in this import because the seeded bodies never extend, so
# the column was dropped rather than committed as a number that means nothing.
# Addresses are 6502 load addresses; they relate to neither DOS address base (see AGENTS.md).
"""


def segments(exdir):
    out = []
    for addr, fn in apple2_image.RESIDENT:
        path = os.path.join(exdir, fn)
        if os.path.exists(path):
            out.append((addr, addr + os.path.getsize(path), fn))
    return sorted(out)


def seg_of(segs, a):
    for lo, hi, f in segs:
        if lo <= a < hi:
            return f
    return "?"


def load(tsv_path, seeds_path, exdir):
    entries = []
    with open(tsv_path) as fh:
        head = fh.readline().rstrip("\n").split("\t")
        for line in fh:
            parts = line.rstrip("\n").split("\t")
            if len(parts) < len(head):
                continue
            rec = dict(zip(head, parts))
            entries.append(rec)
    seeds = sorted(int(l.strip(), 16) for l in open(seeds_path)
                   if l.strip() and not l.startswith("#"))
    segs = segments(exdir)
    rows = []
    for i, rec in enumerate(entries):
        a = int(rec["entry"], 16)
        nxt = next((s for s in seeds if s > a), None)
        span = (nxt - a) if nxt else "?"
        rows.append({"entry": f"${a:04X}", "segment": seg_of(segs, a),
                     "span_bytes": span, "status": rec["decompile_status"]})
    return rows


def render(rows):
    lines = [HEADER.rstrip("\n"), "entry\tsegment\tspan_bytes\tdecompile_status"]
    for r in rows:
        lines.append(f"{r['entry']}\t{r['segment']}\t{r['span_bytes']}\t{r['status']}")
    return "\n".join(lines) + "\n"


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("-t", "--tsv", default=TSV)
    ap.add_argument("-s", "--seeds", default=SEEDS)
    ap.add_argument("-d", "--dir", default="decompiled/apple2")
    ap.add_argument("-o", "--out")
    ap.add_argument("--check", action="store_true",
                    help="compare against the committed file instead of writing")
    a = ap.parse_args()

    if not os.path.exists(a.tsv):
        sys.exit(f"no Ghidra index at {a.tsv}; run tools/apple2_ghidra.sh")
    text = render(load(a.tsv, a.seeds, a.dir))
    if a.check:
        target = a.out or "disasm/apple2-functions.tsv"
        cur = open(target).read() if os.path.exists(target) else ""
        body = "\n".join(l for l in cur.splitlines() if not l.startswith("#"))
        new = "\n".join(l for l in text.splitlines() if not l.startswith("#"))
        if body.strip() == new.strip():
            print(f"{target} matches the current Ghidra index")
            return 0
        print(f"{target} is STALE versus {a.tsv}", file=sys.stderr)
        return 1
    if a.out:
        with open(a.out, "w") as fh:
            fh.write(text)
        print(f"wrote {a.out}: {len(text.splitlines()) - len(HEADER.splitlines()) - 1} functions")
    else:
        sys.stdout.write(text)
    return 0


if __name__ == "__main__":
    sys.exit(main())
