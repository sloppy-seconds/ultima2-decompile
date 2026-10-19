#!/usr/bin/env python3
"""CP6: byte-check decompiler claims against the actual bytes.

For a function entry (cs offset XXXX) and claimed size, disassemble the file range
[XXXX+0x200, XXXX+0x200+size) with objdump and check that integer constants asserted
by a decompiler's C body actually appear as immediates (or byte patterns) in that range.

Usage:
  tools/bytecheck.py --entry 2B8F --size 0x40 --c-file body.c [--json]

The C body is scanned for integer literals (hex and decimal). Literals 0 and 1 are
skipped (frequently implicit: xor reg,reg, inc/dec, boolean tests). For each remaining
literal, it is "present" if its little-endian 1/2/3/4-byte encoding occurs anywhere in
the raw range bytes. Missing literals are reported as flags for human review.

Exit code: 0 if no flags, 1 if any flag, 2 on usage error.
"""
import argparse
import json
import re
import subprocess
import sys

EXE = "original/ultimaii.exe"


def range_bytes(entry: int, size: int) -> bytes:
    with open(EXE, "rb") as f:
        f.seek(entry + 0x200)
        return f.read(size)


def objdump_range(entry: int, size: int) -> str:
    start = entry + 0x200
    stop = start + size
    out = subprocess.run(
        ["objdump", "-D", "-b", "binary", "-m", "i8086", "-j", ".data",
         f"--start-address={start}", f"--stop-address={stop}", EXE],
        capture_output=True, text=True)
    return out.stdout


def literals_from_c(text: str):
    lits = set()
    for m in re.finditer(r"0[xX]([0-9a-fA-F]{1,8})\b", text):
        lits.add(int(m.group(1), 16))
    for m in re.finditer(r"(?<![\w.])\d+(?![\w.])", text):
        v = int(m.group(0))
        if v > 1:
            lits.add(v)
    # Reko renders DS-relative operands as struct field names bXXXX; the offset
    # appears as a 2-byte immediate in the instruction, so it is checkable.
    for m in re.finditer(r"\bb([0-9a-fA-F]{4,6})\b", text):
        lits.add(int(m.group(1), 16))
    # Ghidra renders absolute operands as ram/DS symbols.
    for m in re.finditer(r"(?:DAT_|ram|ds)(?:0x)?([0-9a-fA-F]{4,8})", text):
        lits.add(int(m.group(1), 16))
    lits.discard(0)
    lits.discard(1)
    return sorted(lits)


def present(val: int, raw: bytes) -> bool:
    for n in (1, 2, 3, 4):
        if val < (1 << (8 * n)):
            enc = val.to_bytes(n, "little")
            if enc in raw:
                return True
    return False


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--entry", required=True, help="cs offset XXXX (hex)")
    ap.add_argument("--size", required=True, help="claimed body size (hex or dec)")
    ap.add_argument("--c-file", required=True, help="file containing the C body")
    ap.add_argument("--json", action="store_true")
    a = ap.parse_args()

    entry = int(a.entry, 16)
    size = int(a.size, 0)
    raw = range_bytes(entry, size)
    dis = objdump_range(entry, size)
    lits = literals_from_c(open(a.c_file).read())

    missing = [v for v in lits if not present(v, raw)]
    res = {
        "entry": f"{entry:04X}",
        "file": f"{entry+0x200:04X}",
        "size": size,
        "literals_checked": len(lits),
        "missing": [f"0x{v:X}" for v in missing],
        "verdict": "verified" if not missing else "flag",
    }
    if a.json:
        print(json.dumps(res))
    else:
        print(f"entry {entry:04X} size {size} lits {len(lits)} "
              f"missing {len(missing)} -> {res['verdict']}")
        for v in missing:
            print(f"  MISSING 0x{v:X}")
    return 0 if not missing else 1


if __name__ == "__main__":
    sys.exit(main())
