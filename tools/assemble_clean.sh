#!/usr/bin/env bash
# Phase 3 CP6: rebuild the ENTIRE binary from the CLEANED tree only.
# Each cleaned function file is assembled in isolation (tools/check_func.py
# scaffolding: .org to true origin + extern stub labels) and its proven byte
# range is spliced into the output. Prologue (MZ+PSP) comes from the committed
# data file asm/0000_data_prologue.asm.
#
# Two modes:
#  * local: original/ultimaii.exe present -> full byte-diff vs original.
#  * CI:    original absent (copyrighted, never committed) -> every function
#    still assembled + length-checked (--no-compare), and the spliced output's
#    md5 must equal the known checksum of the original image.
# Exit 0 = rebuild verified.
set -euo pipefail
cd "$(dirname "$0")/.."
OUT=${1:-/var/tmp/u2-clean-rebuild.bin}
python3 - "$OUT" << 'PY'
import glob, hashlib, os, subprocess, sys
from concurrent.futures import ThreadPoolExecutor

BIAS = 0x200
# Known md5 of original/ultimaii.exe (the Internet Archive pack described in
# README/AGENTS.md). A fact, not content — safe to commit, and it is the CI
# oracle: our build must equal it byte-for-byte.
EXPECTED_MD5 = "fe884d5117971073ac8097cc7a6aca25"
EXPECTED_SIZE = 37344

have_orig = os.path.exists("original/ultimaii.exe")
orig = open("original/ultimaii.exe", "rb").read() if have_orig else None
out = bytearray(EXPECTED_SIZE)

# 1) prologue: prefer the committed clean-tree data file
if os.path.exists("asm/0000_data_prologue.asm"):
    prol = "asm/0000_data_prologue.asm"
else:
    prol = "disasm/functions/_prologue.asm"
if os.path.exists(prol):
    subprocess.run(
        ["bash", "-c",
         "{ echo '        .code16'; echo '        .text'; "
         f"sed 's/^\\( *\\)db\\b/\\1.byte/' {prol}; }} > /var/tmp/u2-prol.s "
         "&& as --32 -o /var/tmp/u2-prol.o /var/tmp/u2-prol.s "
         "&& objcopy -j .text -O binary /var/tmp/u2-prol.o /var/tmp/u2-prol.bin"],
        check=True)
    prov = open("/var/tmp/u2-prol.bin", "rb").read()
    out[0x000:0x200] = prov[0x000:0x200]   # mz header
    out[0x200:0x300] = prov[0x200:0x300]   # psp

# 2) every function, in map order, from its cleaned file
rows = [l.split("\t") for l in
        open("disasm/function-map.tsv").read().splitlines()[1:]]
# Each row is assembled by a separate `check_func.py` subprocess: a Python startup, an
# `as`, an `objcopy`, and an `nm`, per function, for ~1222 functions. Run sequentially that
# loop was the whole cost of this script (62s of a 2-minute check_all) on a box with 32
# cores idle. It parallelises cleanly and the isolation is not something this change had to
# introduce: check_func.py already writes only into tmp/check/<SEG>/, a per-segment
# directory, so concurrent runs cannot see each other's files. The one fixed-path work in
# this script is the prologue above, which happens once before the loop.
#
# Order still matters for the splice, so pool.map is used deliberately rather than
# as_completed: it yields results in input order, which keeps the rebuilt bytes identical
# to the sequential build. Verified by md5, not assumed.
def build_row(row):
    s, e, ln, ev, hint = row
    seg = s.upper()
    cmd = [sys.executable, "tools/check_func.py", seg]
    if not have_orig:
        cmd.append("--no-compare")
    c = subprocess.run(cmd, capture_output=True, text=True)
    if c.returncode != 0:
        return ("fail", seg, c.stdout, c.stderr)
    src = c.stdout.split("src=")[1].strip()
    fs, fe = int(s, 16) + BIAS, min(int(e, 16) + BIAS + 1, EXPECTED_SIZE)
    with open(f"tmp/check/{seg}/check.bin", "rb") as f:
        blob = f.read()
    return ("ok", src.startswith("asm/"), fs, fe, blob)


n_clean = n_slice = 0
workers = max(1, min(32, (os.cpu_count() or 4) * 2))
print(f"assembling {len(rows)} functions across {workers} workers")
with ThreadPoolExecutor(max_workers=workers) as pool:
    for res in pool.map(build_row, rows):
        if res[0] == "fail":
            sys.exit(f"check_func FAILED for {res[1]}:\n{res[2]}{res[3]}")
        _, is_clean, fs, fe, blob = res
        if is_clean:
            n_clean += 1
        else:
            n_slice += 1
        out[fs:fe] = blob[fs:fe]

md5 = hashlib.md5(bytes(out)).hexdigest()
open(sys.argv[1], "wb").write(bytes(out))
print(f"cleaned files used: {n_clean}, mechanical-slice fallbacks: {n_slice}")
if have_orig:
    if bytes(out) == orig:
        print(f"CLEAN REBUILD BYTE-MATCH: {len(orig)} bytes identical")
    else:
        d = sum(1 for a, b in zip(orig, out) if a != b)
        sys.exit(f"CLEAN REBUILD MISMATCH: {d} bytes differ")
else:
    print(f"CI mode (no original): md5 {md5} vs known {EXPECTED_MD5}")
    if md5 == EXPECTED_MD5:
        print(f"CLEAN REBUILD CHECKSUM-MATCH: {EXPECTED_SIZE} bytes, md5 OK")
    else:
        sys.exit("CLEAN REBUILD CHECKSUM MISMATCH")
PY
