#!/usr/bin/env python3
"""selfmod_diff.py — reconcile the static bytes of the self-modifying cluster
(seg 0x5120..0x5151, file 0x5320..0x5351) with the bytes Spice86 actually
recorded as executed in the runtime CFG captures.

Reads only in-project evidence:
  captures/spice86/spice86-cfg.json
  captures/external-20261019/**/cfg_blocks.json
  original/ultimaii.exe            (ground truth, read-only)

Prints a per-byte table: static byte vs executed byte(s) observed, and which
capture files observed each. Raw dumps stay out of git; this script is the
regenerator for the curated note in disasm/selfmod-capture.md.

Usage: python3 tools/selfmod_diff.py [--lo 5100] [--hi 5160]
"""
import argparse
import glob
import json
import os
import sys
from collections import defaultdict

PROJECT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
EXE = os.path.join(PROJECT, "original", "ultimaii.exe")
# runtime segment offset -> file offset
FILE_BIAS = 0x200
CODE_SEG = "017D"


def load_exe():
    with open(EXE, "rb") as f:
        return f.read()


def cfg_files():
    out = [os.path.join(PROJECT, "captures", "spice86", "spice86-cfg.json")]
    out += glob.glob(os.path.join(PROJECT, "captures", "external-20261019", "*", "cfg_blocks.json"))
    return [p for p in out if os.path.exists(p)]


def collect(lo, hi):
    """returns {runtime_offset: {bytevalue: set(capture labels)}}"""
    seen = defaultdict(lambda: defaultdict(set))
    blocks_seen = defaultdict(set)
    for path in cfg_files():
        label = os.path.relpath(path, PROJECT)
        try:
            with open(path) as f:
                data = json.load(f)
        except (OSError, ValueError):
            continue
        for blk in data.get("blocks") or []:
            entry = blk.get("entry") or ""
            if ":" not in entry:
                continue
            seg, off = entry.split(":")
            if seg.upper() != CODE_SEG:
                continue
            try:
                start = int(off, 16)
            except ValueError:
                continue
            cur = start
            for item in blk.get("asm") or []:
                hexb = item.split("|", 1)[0].strip()
                if len(hexb) % 2 or any(c not in "0123456789abcdefABCDEF" for c in hexb):
                    break
                raw = bytes.fromhex(hexb)
                for b in raw:
                    if lo <= cur <= hi:
                        seen[cur][b].add(label)
                    cur += 1
                blocks_seen[cur].add(label)
    return seen


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--lo", default="5100")
    ap.add_argument("--hi", default="5160")
    args = ap.parse_args()
    lo, hi = int(args.lo, 16), int(args.hi, 16)

    exe = load_exe()
    seen = collect(lo, hi)

    n_obs = 0
    n_conflict = 0
    n_diff = 0
    print(f"# offset  file    static  executed(obs)            captures")
    for off in range(lo, hi + 1):
        if off not in seen:
            continue
        n_obs += 1
        fpos = off + FILE_BIAS
        static = exe[fpos]
        variants = seen[off]
        vals = sorted(variants)
        if len(vals) > 1:
            n_conflict += 1
        if any(v != static for v in vals):
            n_diff += 1
        marks = ",".join(f"{v:02X}" for v in vals)
        caps = len(next(iter(variants.values())))
        flag = "" if vals == [static] else "   <== DIFFERS"
        print(f"  {off:04X}  {fpos:04X}   {static:02X}    {marks:<22} {caps}{flag}")

    print()
    print(f"observed bytes: {n_obs}/{hi-lo+1}  differing: {n_diff}  conflicting: {n_conflict}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
