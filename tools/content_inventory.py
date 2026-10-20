#!/usr/bin/env python3
"""
content_inventory.py — catalogue the game's data files by STRUCTURE, never content.

Why this exists: the CP4 map work needed to know what every file next to
ultimaii.exe is for, and the answer had to be re-derivable rather than remembered.
This regenerates that catalogue from a content directory in one pass.

It deliberately emits no game content. Sizes, record counts, byte-class ratios and
entropy are facts about the container; the bytes themselves are the player's copy
and stay out of git. That is what lets the TSV be committed while the data files
cannot be (AGENTS.md, Licensing & Commit Policy).

Usage:
    python3 tools/content_inventory.py original/ > disasm/content-inventory.tsv
    python3 tools/content_inventory.py original/ --check     # exit 1 on surprises
    python3 tools/content_inventory.py original/ --tlkx-sample 3   # decode shape only

The --check invariants are the ones proven in docs/phase4-implementation.md § CP4:
  * mapxNN  = 4096 tile bytes + a 128-byte tail whose first byte is 0x1A
  * monxNN  = 256 monster-ID slots + the same tail shape
  * tlkxNN  = high-bit-set ASCII (Apple II convention): byte 0 is a marker and
              essentially every later byte has 0x80 set
  * pic*    = full-screen 2bpp pictures, read by asm/03AC with CX=0x4000
  * the exe references PICCAS, which this pack does not ship
"""

import argparse
import collections
import math
import os
import re
import sys

# FCB names the game opens, found as inline bytes in the code stream. The two-digit
# ones are completed at run time by self-patching (asm/2290: MAPX + digits).
PIC_FCB_RE = re.compile(rb"PIC[A-Z$]{3}  ")
SECTOR_FCB_RE = re.compile(rb"(MAPX|MONX|TLKX)[A-Z0-9]{2}  ")
PLAYER_FCB = b"PLAYER  "
PREFIX_CLASSES = {
    "MAPX": ("map", 4096),
    "MONX": ("mon", 256),
    "TLKX": ("tlk", 256),
}


def entropy(buf):
    if not buf:
        return 0.0
    counts = collections.Counter(buf)
    n = len(buf)
    return -sum((c / n) * math.log2(c / n) for c in counts.values())


def classify(name):
    stem = name.split(".")[0].lower()
    m = re.fullmatch(r"(mapx|monx|tlkx)(\d\d)", stem)
    if m:
        return PREFIX_CLASSES[m.group(1).upper()][0], m.group(2)
    if stem.startswith("pic"):
        return "pic", stem[3:]
    if stem == "monsters":
        return "monsters", ""
    if stem == "player":
        return "player", ""
    if name.lower().endswith(".exe"):
        return "exe", ""
    return "other", ""


def scan_file(path, name):
    with open(path, "rb") as f:
        buf = f.read()
    kind, key = classify(name)
    size = len(buf)
    body = size - 128 if size >= 128 else size
    tail = buf[body:] if size >= 128 else b""
    hi = sum(1 for x in buf[1:] if x & 0x80)
    nz = sum(1 for x in buf[1:] if x)
    printable = sum(1 for x in buf if 32 <= x < 127)
    return {
        "file": name,
        "class": kind,
        "key": key,
        "size": size,
        "body": body,
        "tail0": tail[0] if tail else "",
        "tail_nonzero": sum(1 for x in tail[1:] if x),
        "distinct": len(set(buf)),
        "entropy": round(entropy(buf), 3),
        "highbit_ratio": round(hi / max(1, nz), 3),
        "nonzero": nz,
        "printable_ratio": round(printable / max(1, size), 3),
    }


def exe_fcb_names(exe_path):
    """The file names the code opens, as inline FCB bytes.

    Matched with targeted patterns rather than a generic 'looks like an FCB' scan:
    a generic scan swallows the instruction byte in front of the name (the shipped
    bytes are e.g. `50 PICDRA  `), which silently drops the first picture.
    """
    if not os.path.exists(exe_path):
        return set()
    with open(exe_path, "rb") as f:
        data = f.read()
    found = set()
    for m in PIC_FCB_RE.finditer(data):
        found.add(m.group()[:6].decode("latin-1").upper())
    for m in SECTOR_FCB_RE.finditer(data):
        found.add(m.group()[:6].decode("latin-1").upper())
    if PLAYER_FCB in data:
        found.add("PLAYER")
    return found


def check(rows, exe_path, content_dir):
    """Structural invariants. Reports surprises; never prints content bytes."""
    problems = []
    have = {r["file"].lower() for r in rows}

    for r in rows:
        if r["class"] == "map":
            if r["body"] != 4096:
                problems.append(f"{r['file']}: body {r['body']} != 4096 tile bytes")
            if r["size"] not in (4096, 4224):
                problems.append(f"{r['file']}: size {r['size']} is neither 4096 nor 4224")
            if r["tail0"] != 0x1A and r["size"] == 4224:
                problems.append(f"{r['file']}: tail byte 0 is {r['tail0']:#04x}, expected 0x1a")
        elif r["class"] == "mon":
            if r["body"] != 256:
                problems.append(f"{r['file']}: body {r['body']} != 256 monster slots")
        elif r["class"] == "tlk":
            if r["highbit_ratio"] < 0.9:
                problems.append(
                    f"{r['file']}: only {r['highbit_ratio']} of non-zero bytes have the "
                    "high bit set (expected ~1.0 for Apple II high-bit text)"
                )

    names = exe_fcb_names(exe_path)
    for pic in sorted(n for n in names if n.startswith("PIC") and "XXX" not in n):
        if pic.lower() not in have:
            problems.append(f"exe references {pic} but the content dir has no {pic.lower()}")

    return problems


def tlkx_shape(path, limit):
    """Show the DECODE SHAPE of talk files without reproducing the text:
    lengths, line count and the character classes used, not the words."""
    with open(path, "rb") as f:
        buf = f.read()
    dec = bytes((x & 0x7F) for x in buf[1:] if x)
    lines = [ln for ln in dec.replace(b"\r", b"\n").split(b"\n") if ln]
    print(f"{os.path.basename(path)}: {len(buf)} bytes -> {len(dec)} decoded, "
          f"{len(lines)} records")
    for i, ln in enumerate(lines[:limit]):
        letters = sum(1 for c in ln if 65 <= c <= 90)
        print(f"   record {i}: len={len(ln)} uppercase_letters={letters} "
              f"has_colon={1 if 58 in ln else 0} (text not reproduced)")


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("content_dir", help="directory holding mapxNN / monxNN / tlkxNN / pic*")
    ap.add_argument("--exe", default=None, help="path to ultimaii.exe (default: <dir>/ultimaii.exe)")
    ap.add_argument("--check", action="store_true", help="verify structural invariants")
    ap.add_argument("--tlkx-sample", type=int, default=0, metavar="N",
                    help="print the decode shape of N talk files (no text)")
    args = ap.parse_args()

    exe = args.exe or os.path.join(args.content_dir, "ultimaii.exe")
    rows = []
    for name in sorted(os.listdir(args.content_dir)):
        p = os.path.join(args.content_dir, name)
        if not os.path.isfile(p):
            continue
        if name.lower().endswith((".bat", ".pif")):
            continue
        rows.append(scan_file(p, name))

    cols = ["file", "class", "key", "size", "body", "tail0", "tail_nonzero",
            "distinct", "entropy", "nonzero", "highbit_ratio", "printable_ratio"]
    print("\t".join(cols))
    for r in rows:
        print("\t".join(str(r[c]) for c in cols))

    if args.tlkx_sample:
        print("", file=sys.stderr)
        for r in [x for x in rows if x["class"] == "tlk"][: args.tlkx_sample]:
            tlkx_shape(os.path.join(args.content_dir, r["file"]), 3)

    if args.check:
        problems = check(rows, exe, args.content_dir)
        for p in problems:
            print("SURPRISE: " + p, file=sys.stderr)
        print(f"checked {len(rows)} files: "
              f"{'clean' if not problems else str(len(problems)) + ' surprise(s)'}",
              file=sys.stderr)
        return 1 if problems else 0
    return 0


if __name__ == "__main__":
    sys.exit(main())
