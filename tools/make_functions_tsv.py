#!/usr/bin/env python3
"""CP7: consolidate Phase 1 evidence into disasm/functions.tsv.

Columns: entry  size_bytes  ghidra_status  reko_status  bytecheck  confidence  source
  size_bytes     Ghidra claimed body size; entry->next-entry span when Ghidra has no body
  ghidra_status  ok | failed:<msg> | absent
  reko_status    defined | absent
  bytecheck      verdict from bytecheck-report.md row, or '-' when not sampled
  confidence     high  = ghidra ok + reko defined + bytecheck verified
                 med   = ghidra ok + bytecheck verified (reko absent)
                 low   = anything else with any evidence
  source         cfg | jump-table | both
"""
import csv

SEEDS = "disasm/seed-entries.txt"
CFG = "disasm/entry-points.txt"
JT = "disasm/jump-table.txt"
GIDX = "decompiled/ghidra/ultimaii-functions.tsv"
RC = "decompiled/reko/ultimaii.c"
BCR = "disasm/bytecheck-report.md"
OUT = "disasm/functions.tsv"

import re


def main():
    seeds = sorted(int(l.split()[0], 16) for l in open(SEEDS))
    cfg = set(int(l.split()[0], 16) for l in open(CFG))
    jt = set(int(l.split()[0], 16) for l in open(JT))

    g = {}
    with open(GIDX) as f:
        f.readline()
        for line in f:
            p = line.rstrip("\n").split("\t")
            if len(p) >= 5:
                g[int(p[0].split(":")[1], 16)] = (int(p[3]), p[4])

    reko = set(int(m, 16) for m in
               re.findall(r"^define fn0800_([0-9a-fA-F]{4})$", open(RC).read(), re.M))

    bc = {}
    try:
        for line in open(BCR):
            m = re.match(r"\| ([0-9A-F]{4}) \|.*\| (verified|mismatch|unverified) \|\s*$", line)
            if m:
                bc[int(m.group(1), 16)] = m.group(2)
    except FileNotFoundError:
        pass

    with open(OUT, "w", newline="") as f:
        w = csv.writer(f, delimiter="\t")
        w.writerow(["entry", "size_bytes", "ghidra_status", "reko_status",
                    "bytecheck", "confidence", "source"])
        for i, e in enumerate(seeds):
            nxt = seeds[i + 1] if i + 1 < len(seeds) else 0x6000
            span = nxt - e
            gsz, gst = g.get(e, (None, "absent"))
            size = gsz if gsz else span
            g_ok = gst == "ok"
            r_def = e in reko
            bcv = bc.get(e, "-")
            if g_ok and bcv == "verified":
                conf = "high" if r_def else "med"
            else:
                conf = "low"
            src = ("both" if e in cfg and e in jt else
                   "jump-table" if e in jt else "cfg")
            w.writerow([f"{e:04X}", size, gst.split(":")[0] if gst != "absent" else "absent",
                        "defined" if r_def else "absent", bcv, conf, src])
    print(f"wrote {OUT}: {len(seeds)} rows "
          f"(ghidra ok {sum(1 for e in seeds if g.get(e,('', ''))[1]=='ok')}, "
          f"reko {len(reko)}, bytechecked {len(bc)})")


if __name__ == "__main__":
    main()
