#!/usr/bin/env bash
# Phase 2 CP3: rebuild the whole binary from per-function slices and byte-diff.
# Exit 0 = slices reproduce original/ultimaii.exe byte-for-byte.
set -euo pipefail
cd "$(dirname "$0")/.."
OUT=${1:-/var/tmp/u2-rebuild.bin}
{
  echo "        .code16"
  echo "        .text"
  cat disasm/functions/_prologue.asm
  ls disasm/functions/[0-9A-F]*.asm | sort | xargs cat
} > /var/tmp/u2-rebuild.s
as --32 -o "$OUT.o" /var/tmp/u2-rebuild.s 2>/dev/null
objcopy -j .text -O binary "$OUT.o" "$OUT"
python3 - "$OUT" << 'PY'
import sys
orig = open("original/ultimaii.exe", "rb").read()
out = open(sys.argv[1], "rb").read()[: len(orig)]
if orig == out:
    print(f"REBUILD BYTE-MATCH: {len(orig)} bytes identical")
else:
    print("REBUILD MISMATCH:", sum(1 for a, b in zip(orig, out) if a != b), "bytes differ")
    sys.exit(1)
PY
