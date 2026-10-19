#!/usr/bin/env python3
"""CP1: extract deduped routine entry points from the Spice86 runtime CFG.

Rules (docs/phase1-plan.md CP1):
  * keep blocks whose entry segment is the game code segment (017D)
  * drop a block flagged `dead` ONLY if it has no live (non-dead) predecessor
  * dedup by offset, sort ascending
  * emit one 4-hex-digit offset per line, `XXXX  # block=<id>`
"""
import json
import sys
from collections import defaultdict

CFG = "captures/spice86/spice86-cfg.json"
OUT = "disasm/entry-points.txt"
CODE_SEG = "017D"


def main():
    with open(CFG) as f:
        cfg = json.load(f)
    blocks = cfg["blocks"]
    by_id = {b["id"]: b for b in blocks}

    kept, dropped = [], []
    seg_counts = defaultdict(int)
    for b in blocks:
        seg, off = b["entry"].split(":")
        seg_counts[seg] += 1
        if seg.upper() != CODE_SEG:
            continue
        if b.get("dead"):
            live_preds = [p for p in b.get("pred", [])
                          if p in by_id and not by_id[p].get("dead")]
            if not live_preds:
                dropped.append(b)
                continue
        kept.append(b)

    # dedup by offset; keep the lowest block id for the comment
    best = {}
    for b in kept:
        off = int(b["entry"].split(":")[1], 16)
        if off not in best or b["id"] < best[off]["id"]:
            best[off] = b

    rows = sorted(best.items())
    with open(OUT, "w") as f:
        for off, b in rows:
            f.write(f"{off:04X}  # block={b['id']}\n")

    print(f"blocks total={len(blocks)} seg_counts={dict(seg_counts)}")
    print(f"code-seg kept={len(kept)} dead-dropped={len(dropped)} "
          f"unique-offsets={len(rows)} -> {OUT}")
    dupes = len(kept) - len(rows)
    print(f"duplicates removed={dupes}")
    if dropped:
        print("dropped dead blocks:",
              ", ".join(f"{b['entry']}(id={b['id']})" for b in dropped))


if __name__ == "__main__":
    sys.exit(main())
