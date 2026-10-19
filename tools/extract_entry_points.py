#!/usr/bin/env python3
"""CP1(v2): extract deduped routine entry points from ALL runtime CFGs.

Sources:
  * captures/spice86/spice86-cfg.json            (original in-project playthrough)
  * captures/external-20261019/*/cfg_blocks.json (user-authorized external captures;
    see captures/external-20261019/PROVENANCE.md)

Rules (unchanged from the plan, applied per source file):
  * keep blocks whose entry segment is the game code segment (017D)
  * drop a block flagged `dead` only if it has no live (non-dead) predecessor
    (predecessor ids are per-file; cross-file offsets still union)
  * dedup by offset, sort ascending
Emit one 4-hex-digit offset per line: `XXXX  # block=<id> src=<name>`.
"""
import glob
import json
import os
import sys
from collections import defaultdict

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CODE_SEG = "017D"


def sources():
    yield "spice86-cfg", os.path.join(ROOT, "captures/spice86/spice86-cfg.json")
    for p in sorted(glob.glob(os.path.join(ROOT, "captures/external-20261019/*/cfg_blocks.json"))):
        yield os.path.basename(os.path.dirname(p)), p


def main():
    best = {}   # offset -> (block, src)
    per_src = {}
    for name, path in sources():
        with open(path) as f:
            cfg = json.load(f)
        blocks = cfg["blocks"]
        by_id = {b["id"]: b for b in blocks}
        kept = 0
        for b in blocks:
            seg, off = b["entry"].split(":")
            if seg.upper() != CODE_SEG:
                continue
            if b.get("dead"):
                live = [p for p in b.get("pred", [])
                        if p in by_id and not by_id[p].get("dead")]
                if not live:
                    continue
            kept += 1
            o = int(off, 16)
            if o not in best or b["id"] < best[o][0]["id"]:
                best[o] = (b, name)
        per_src[name] = (len(blocks), kept)

    rows = sorted(best.items())
    out = os.path.join(ROOT, "disasm/entry-points.txt")
    with open(out, "w") as f:
        for o, (b, src) in rows:
            f.write(f"{o:04X}  # block={b['id']} src={src}\n")

    print(f"sources: {len(per_src)}")
    for n, (tot, kept) in per_src.items():
        print(f"  {n}: blocks={tot} kept={kept}")
    print(f"UNIQUE entry offsets emitted: {len(rows)} -> {out}")


if __name__ == "__main__":
    sys.exit(main())
