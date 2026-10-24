#!/usr/bin/env python3
"""Build a flat 6502 memory image from the extracted Apple II BIN files.

The Apple BIN aux type is the load address (see docs/apple2-reference.md), but the
files are separate segments with gaps and, in one case, a genuine overlay: CREATE
loads at $6000 inside ULTIMA.II.OBJ, which spans $5000-$8688. Ghidra needs one
coherent address space to resolve the JSR $4006 -> JMP $4080 -> JSR $9712 chain,
so this lays down the non-overlapping resident set and refuses to guess about the
rest.

    python3 tools/apple2_image.py -o /var/tmp/u2_6502.bin [--with create]

Gaps are zero-filled. Zero is a real byte value in 6502 code, so the manifest
printed on stdout is what tells you which ranges are backed by file bytes.
"""

import argparse
import os
import sys

# load address -> file name, for the resident set that can coexist
RESIDENT = [
    (0x4000, "STD.SUBS.OBJ"),
    (0x5000, "ULTIMA.II.OBJ"),
    (0x8900, "DNGDRAW.OBJ"),
    (0x903C, "TABLES.903C.OBJ"),
    (0x9700, "BIOS.SUBS"),
]
# overlays: only one of these may occupy a given range, so they are opt-in
OVERLAYS = {
    "create": (0x6000, "CREATE"),
}
BASE = 0x4000
# BIOS.SUBS is 2592 bytes at $9700, so it ends at $A120; $B000 leaves headroom
# without inventing address space nobody uses.
LIMIT = 0xB000


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("-d", "--dir", default="decompiled/apple2", help="extracted Apple files")
    ap.add_argument("-o", "--out", required=True)
    ap.add_argument("--with", dest="overlay", action="append", default=[],
                    help=f"opt-in overlay: {', '.join(OVERLAYS)}")
    args = ap.parse_args()

    if not os.path.isdir(args.dir):
        sys.exit(f"no such dir {args.dir!r}; extract it first (docs/apple2-reference.md § 2)")

    plan = list(RESIDENT)
    for name in args.overlay:
        if name not in OVERLAYS:
            sys.exit(f"unknown overlay {name!r}; choose from {', '.join(OVERLAYS)}")
        plan.append(OVERLAYS[name])

    img = bytearray(LIMIT - BASE)
    manifest = []
    for addr, fn in plan:
        path = os.path.join(args.dir, fn)
        if not os.path.exists(path):
            sys.exit(f"missing {path}; run cp2 extract first")
        data = open(path, "rb").read()
        off = addr - BASE
        if off + len(data) > len(img):
            sys.exit(f"{fn} at ${addr:04X} + {len(data)} exceeds ${LIMIT:04X}")
        img[off:off + len(data)] = data
        manifest.append((addr, len(data), fn))

    # prove the plan really is non-overlapping rather than assuming it
    manifest.sort()
    for (a1, l1, f1), (a2, l2, f2) in zip(manifest, manifest[1:]):
        if a1 + l1 > a2:
            sys.exit(f"overlap: {f1} (${a1:04X}+{l1}) runs into {f2} (${a2:04X})")

    open(args.out, "wb").write(bytes(img))
    print(f"# wrote {args.out}: {len(img)} bytes, base ${BASE:04X}")
    print(f"{'LOAD':>7} {'SIZE':>7}  FILE")
    for addr, ln, fn in manifest:
        print(f"${addr:04X} {ln:>7}  {fn}")
    print("# unloaded ranges (zero-filled, not real bytes):")
    cursor = BASE
    for addr, ln, fn in manifest:
        if addr > cursor:
            print(f"#   ${cursor:04X}-${addr-1:04X}")
        cursor = addr + ln
    if cursor < LIMIT:
        print(f"#   ${cursor:04X}-${LIMIT-1:04X}")


if __name__ == "__main__":
    main()
