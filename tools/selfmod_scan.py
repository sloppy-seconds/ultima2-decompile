#!/usr/bin/env python3
"""selfmod_scan.py — find every runtime-offset where the bytes Spice86 recorded
as executed differ from the static bytes in original/ultimaii.exe.

If the runtime CFG export reflects live memory, the mismatches it reports ARE
the self-modifying / relocation-fixup sites — evidence for the CP0 selfmod
capture note. Zero mismatches means the export mirrors the image, not memory,
and the note must say so.

Usage: python3 tools/selfmod_scan.py [--window 4]
"""
import argparse
import glob
import json
import os
import sys
from collections import defaultdict

PROJECT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
EXE = os.path.join(PROJECT, "original", "ultimaii.exe")
FILE_BIAS = 0x200
CODE_SEG = "017D"


def cfg_files():
    out = [os.path.join(PROJECT, "captures", "spice86", "spice86-cfg.json")]
    out += glob.glob(os.path.join(PROJECT, "captures", "external-20261019", "*", "cfg_blocks.json"))
    return [p for p in out if os.path.exists(p)]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--window", type=int, default=4, help="context bytes around each mismatch")
    ap.add_argument("--probe", default="",
                    help="comma list of lo-hi runtime ranges to report observed status for, e.g. 4f00-4f10,5120-5151")
    args = ap.parse_args()

    exe = open(EXE, "rb").read()
    # runtime offset -> {byte: set(labels)}
    obs = defaultdict(lambda: defaultdict(set))
    total_blocks = 0
    for path in cfg_files():
        label = os.path.relpath(path, PROJECT)
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
            total_blocks += 1
            cur = int(off, 16)
            for item in blk.get("asm") or []:
                hexb = item.split("|", 1)[0].strip()
                if len(hexb) % 2 or any(c not in "0123456789abcdefABCDEF" for c in hexb):
                    break
                for b in bytes.fromhex(hexb):
                    obs[cur][b].add(label)
                    cur += 1

    mismatches = []
    for off in sorted(obs):
        fpos = off + FILE_BIAS
        if fpos >= len(exe):
            continue
        static = exe[fpos]
        vals = sorted(obs[off])
        if any(v != static for v in vals):
            mismatches.append((off, static, vals, len(vals)))

    span_lo = min(obs) if obs else 0
    span_hi = max(obs) if obs else 0
    print(f"captures: {len(cfg_files())}  code blocks: {total_blocks}  "
          f"bytes observed: {len(obs)}  span {span_lo:04X}..{span_hi:04X}")
    print(f"mismatching bytes: {len(mismatches)}")
    for off, static, vals, nvals in mismatches:
        fpos = off + FILE_BIAS
        w = args.window
        ctx_s = exe[max(0, fpos - w):fpos + w + 1].hex()
        caps = sorted(next(iter(obs[off].values())))
        where = ", ".join(os.path.basename(os.path.dirname(c)) if "external" in c else c
                          for c in caps[:3])
        print(f"  +0x{off:04X} (file 0x{fpos:04X}) static {static:02X} executed "
              f"{','.join(f'{v:02X}' for v in vals)}  ctx[{ctx_s}]  in {len(caps)} capture(s): {where}")

    if args.probe:
        print()
        for spec in args.probe.split(","):
            lo_s, hi_s = spec.strip().split("-")
            lo, hi = int(lo_s, 16), int(hi_s, 16)
            obs_in = [o for o in obs if lo <= o <= hi]
            diff_in = [o for o, s, v, n in mismatches if lo <= o <= hi]
            print(f"probe {lo:04X}..{hi:04X}: observed {len(obs_in)}/{hi-lo+1} bytes, "
                  f"differing {len(diff_in)}"
                  + (f" at {', '.join(f'{o:04X}' for o in diff_in)}" if diff_in else ""))
    return 0


if __name__ == "__main__":
    sys.exit(main())
