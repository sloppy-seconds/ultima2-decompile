#!/usr/bin/env python3
"""Full-corpus pseudo-C byte validation (not a sample).

For every seed entry: check every constant/operand claimed by the Reko define
(and the Ghidra body when present) against the bytes of the claimed range.
Emits disasm/bytecheck-full.tsv (per-entry verdicts) and prints a summary.
Same claim-extraction rules as tools/bytecheck.py (see CP6 methodology).
"""
import sys

sys.path.insert(0, "tools")
import bytecheck_sample as bs  # noqa: E402


def main():
    seeds = bs.load_seeds()
    gidx, gbodies = bs.load_ghidra()
    rdefs, rranges = bs.load_reko()
    import bisect
    rows = []
    for i, e in enumerate(seeds):
        nxt = seeds[i + 1] if i + 1 < len(seeds) else 0x6000
        g = gidx.get(e)
        gbody = gbodies.get(e, "")
        gfailed = g is None or g["status"] != "ok"
        if gfailed:
            gl, gm, _ = [], [], {}
        else:
            gl, gm, _ = bs.check(e, max(g["size"], 2), gbody, "ghidra")
        rbody = rdefs.get(e, "")
        if rbody:
            rlo, rhi = rranges.get(e, (e, nxt))
            rspan = max(rhi - rlo + 6, 2)
            rl, rm, _ = bs.check(rlo, rspan, rbody, "reko")
        else:
            rl, rm = [], []
        if not (gl or rl):
            v = "no-claims"
        elif not (gm or rm):
            v = "verified"
        else:
            v = "mismatch"
        rows.append((e, v, len(gl), len(gm), len(rl), len(rm),
                     "ok" if not gfailed else ("failed" if g else "absent")))
    with open("disasm/bytecheck-full.tsv", "w") as f:
        f.write("entry\tverdict\tg_lits\tg_missing\tr_lits\tr_missing\tghidra\n")
        for e, v, a, b, c, d, gst in rows:
            f.write(f"{e:04X}\t{v}\t{a}\t{b}\t{c}\t{d}\t{gst}\n")
    from collections import Counter
    print("total:", len(rows), dict(Counter(r[1] for r in rows)))
    mm = [r for r in rows if r[1] == "mismatch"]
    print("mismatch entries:", len(mm))
    print("  with ghidra missing:", sum(1 for r in mm if r[3]))
    print("  with reko missing:", sum(1 for r in mm if r[5]))
    print("  ghidra-ok among mismatches:", sum(1 for r in mm if r[6] == "ok"))


if __name__ == "__main__":
    main()
