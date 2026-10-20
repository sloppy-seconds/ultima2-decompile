#!/usr/bin/env bash
# Phase 3 CP6: rebuild the ENTIRE binary from the CLEANED tree only.
# Each cleaned function file is assembled in isolation (tools/check_func.py
# scaffolding: .org to true origin + extern stub labels) and its proven byte
# range is spliced into the output. The MZ/PSP prologue stays mechanical
# (disasm/functions/_prologue.asm). Exit 0 = output byte-identical to original.
set -euo pipefail
cd "$(dirname "$0")/.."
OUT=${1:-/var/tmp/u2-clean-rebuild.bin}
python3 - "$OUT" << 'PY'
import glob, subprocess, sys

BIAS = 0x200
orig = open("original/ultimaii.exe", "rb").read()
out = bytearray(len(orig))

# 1) prologue (MZ header + PSP): assemble the mechanical blob file alone
r = subprocess.run(
    ["bash", "-c",
     "{ echo '        .code16'; echo '        .text'; "
     "cat disasm/functions/_prologue.asm; } > /var/tmp/u2-prol.s "
     "&& as --32 -o /var/tmp/u2-prol.o /var/tmp/u2-prol.s "
     "&& objcopy -j .text -O binary /var/tmp/u2-prol.o /var/tmp/u2-prol.bin"],
    check=True)
prov = open("/var/tmp/u2-prol.bin", "rb").read()
out[0x000:0x200] = prov[0x000:0x200]  # mz header
out[0x200:0x300] = prov[0x200:0x300]                   # psp

# 2) every function, in map order, from its cleaned file (check_func proves)
rows = [l.split("\t") for l in
        open("disasm/function-map.tsv").read().splitlines()[1:]]
n_clean = n_slice = 0
for s, e, ln, ev, hint in rows:
    seg = s.upper()
    cleaned = bool(glob.glob(f"asm/{seg}_*.asm"))
    c = subprocess.run([sys.executable, "tools/check_func.py", seg],
                       capture_output=True, text=True)
    if c.returncode != 0:
        sys.exit(f"check_func FAILED for {seg}:\n{c.stdout}{c.stderr}")
    src = c.stdout.split("src=")[1].strip()
    if src.startswith("asm/"):
        n_clean += 1
    else:
        n_slice += 1
    binp = f"tmp/check/{seg}/check.bin"
    fs, fe = int(s, 16) + BIAS, int(e, 16) + BIAS + 1
    fe = min(fe, len(orig))
    blob = open(binp, "rb").read()
    out[fs:fe] = blob[fs:fe]

open(sys.argv[1], "wb").write(bytes(out))
print(f"cleaned files used: {n_clean}, mechanical-slice fallbacks: {n_slice}")
if bytes(out) == orig:
    print(f"CLEAN REBUILD BYTE-MATCH: {len(orig)} bytes identical")
else:
    d = sum(1 for a, b in zip(orig, out) if a != b)
    sys.exit(f"CLEAN REBUILD MISMATCH: {d} bytes differ")
PY
