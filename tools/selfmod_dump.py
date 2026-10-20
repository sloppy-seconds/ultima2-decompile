#!/usr/bin/env python3
"""selfmod_dump.py — print the executed instruction stream (Spice86 block asm)
for a runtime-offset window, deduplicated across all captures.

This is the regenerator for the curated evidence in disasm/selfmod-capture.md:
what the CPU actually ran in the seg 0x5120..0x5151 cluster, per capture,
against the static Phase 3 decode.

Usage: python3 tools/selfmod_dump.py [--lo 5120] [--hi 5151]
"""
import argparse
import glob
import json
import os
from collections import defaultdict

PROJECT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CODE_SEG = "017D"


def cfg_files():
    out = [os.path.join(PROJECT, "captures", "spice86", "spice86-cfg.json")]
    out += glob.glob(os.path.join(PROJECT, "captures", "external-20261019", "*", "cfg_blocks.json"))
    return [p for p in out if os.path.exists(p)]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--lo", default="5120")
    ap.add_argument("--hi", default="5151")
    args = ap.parse_args()
    lo, hi = int(args.lo, 16), int(args.hi, 16)

    # runtime offset -> (hexbytes, text) ; count of captures
    instr = {}
    starts = defaultdict(int)
    for path in cfg_files():
        try:
            data = json.load(open(path))
        except (OSError, ValueError):
            continue
        for blk in data.get("blocks") or []:
            entry = blk.get("entry") or ""
            if ":" not in entry:
                continue
            seg, off = entry.split(":")
            if seg.upper() != CODE_SEG:
                continue
            cur = int(off, 16)
            if not (lo <= cur <= hi):
                continue
            starts[cur] += 1
            for item in blk.get("asm") or []:
                hexb, _, text = item.partition("|")
                hexb = hexb.strip()
                if len(hexb) % 2 or any(c not in "0123456789abcdefABCDEF" for c in hexb):
                    break
                if cur not in instr:
                    instr[cur] = (hexb, text.strip())
                cur += len(bytes.fromhex(hexb))

    print(f"# executed instruction stream, runtime {lo:04X}..{hi:04X} "
          f"(file {lo+0x200:04X}..{hi+0x200:04X})")
    print(f"# block entry points seen in this window: "
          + ", ".join(f"{s:04X}({n})" for s, n in sorted(starts.items())))
    print("# off   bytes        executed decode")
    for off in sorted(instr):
        if off > hi:
            break
        hexb, text = instr[off]
        print(f"  {off:04X}  {hexb:<12}  {text}")
    return 0


if __name__ == "__main__":
    main()
