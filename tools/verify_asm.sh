#!/usr/bin/env bash
# Byte-match verification for the extracted ground-truth asm.
# Assembles disasm/ultimaii.asm with GNU as (.code16) and diffs the raw
# output against original/ultimaii.exe. Exit 0 = byte-identical.
# Note: uses GNU as (--32 + .code16) because jwasm is not installed on this
# host; the AGENTS.md Makefile target can swap in jwasm when available.
set -euo pipefail
cd "$(dirname "$0")/.."
OUT=${1:-/var/tmp/u2-verify-asm.bin}
as --32 -o "$OUT.o" disasm/ultimaii.asm
objcopy -j .text -O binary "$OUT.o" "$OUT"
python3 - "$OUT" << 'PY'
import sys
orig = open("original/ultimaii.exe", "rb").read()
out = open(sys.argv[1], "rb").read()[: len(orig)]
if orig == out:
    print(f"BYTE-MATCH: {len(orig)} bytes identical")
else:
    diffs = sum(1 for a, b in zip(orig, out) if a != b)
    print(f"MISMATCH: {diffs} bytes differ")
    sys.exit(1)
PY
