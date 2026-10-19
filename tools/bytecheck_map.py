#!/usr/bin/env python3
"""CP4: bytecheck v2 — pseudo-C claims checked against TRUE function ranges
from disasm/function-map.tsv (replaces the next-seed heuristic).
Reko side is authoritative this phase (Ghidra frozen per owner decision).
Emits disasm/bytecheck-map.tsv + delta summary vs Phase 1 full-corpus run.
"""
import sys

sys.path.insert(0, "tools")
import bytecheck_sample as bs  # noqa: E402


def main():
    bs.RC = "decompiled/reko-map/ultimaii.c"
    bs.RDIS = "decompiled/reko-map/ultimaii.dis"
    fmap = [l.split("\t") for l in
            open("disasm/function-map.tsv").read().splitlines()[1:]]
    rdefs, _ = bs.load_reko()
    rows = []
    for s, e, ln, ev, hint in fmap:
        si, ei = int(s, 16), int(e, 16)
        body = rdefs.get(si, "")
        if not body:
            rows.append((s, "absent", 0, 0, 0))
            continue
        lits, miss, ctx = bs.check(si, ei - si + 1, body, "reko")
        fab = sum(1 for v in miss if ctx[f"0x{v:X}"][1] == "absent-from-file")
        drift = len(miss) - fab
        v = "no-claims" if not lits else ("verified" if not miss else "mismatch")
        rows.append((s, v, len(lits), drift, fab))
    with open("disasm/bytecheck-map.tsv", "w") as f:
        f.write("start\tverdict\tlits\tdrift\tfabricated\n")
        for r in rows:
            f.write("\t".join(str(x) for x in r) + "\n")
    from collections import Counter
    c = Counter(r[1] for r in rows)
    print("map-range verdicts:", dict(c))
    print("total drift flags:", sum(r[3] for r in rows),
          "| total fabricated:", sum(r[4] for r in rows))
    fab_e = [(r[0], r[4]) for r in rows if r[4]]
    print("fabricating functions:", fab_e)
    mism = [(r[0], r[3]) for r in rows if r[1] == "mismatch"]
    print("mismatch functions:", len(mism), "| top drift:",
          sorted(mism, key=lambda x: -x[1])[:8])


if __name__ == "__main__":
    main()
