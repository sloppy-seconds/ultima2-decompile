#!/usr/bin/env python3
"""Phase-2-style ground-truth asm extraction with byte-match validation.

Disassembles a file range of original/ultimaii.exe with objdump (i8086, AT&T),
emits a GNU-as source (.code16 + .org so PCs match file offsets), assembles it
back, and byte-diffs against the original range. Any instruction that will not
round-trip is replaced by its raw .byte encoding (iteratively), so the final
asm is guaranteed byte-identical where possible and reports what was forced.

Usage: tools/extract_asm.py --start 0x200 --end 0x7610 --out disasm/code0.asm
"""
import argparse
import re
import subprocess
import sys

EXE = "original/ultimaii.exe"


def objdump_lines(start, end):
    out = subprocess.run(
        ["objdump", "-d", "-b", "binary", "-m", "i8086", "-j", ".data",
         f"--start-address={start}", f"--stop-address={end}", EXE],
        capture_output=True, text=True).stdout
    rows = []
    for line in out.splitlines():
        m = re.match(r"\s+([0-9a-f]+):\t((?:[0-9a-f]{2} )+) *\t(.*)", line)
        if m:
            addr = int(m.group(1), 16)
            raw = bytes.fromhex(m.group(2).replace(" ", ""))
            text = m.group(3).split("#")[0].rstrip()
            rows.append((addr, raw, text))
    return rows


REL_OPS = {"call", "jmp", "jne", "je", "jb", "jbe", "ja", "jae", "js", "js",
           "jns", "jl", "jge", "jg", "jle", "jc", "jnc", "jz", "jnz", "jp",
           "jnp", "jo", "jno", "loop", "loope", "loopne", "loopz", "loopnz",
           "jcxz", "jecxz"}


def emit_asm(rows, start, end, forced):
    addrs = {ad for ad, _, _ in rows}
    lines = [f"# ground-truth asm for file range {start:#x}..{end:#x}",
             "        .code16", "        .text"]
    pos = start
    for i, (addr, raw, text) in enumerate(rows):
        if addr > pos:
            pad = open(EXE, "rb").read()[pos:addr]
            lines.append("        .byte " + ",".join(f"0x{b:02x}" for b in pad))
        lines.append(f"L_{addr:06x}:")
        if addr in forced:
            lines.append(f"        .byte {','.join('0x%02x' % b for b in raw)}"
                         f"  # forced: {text}")
        else:
            # rewrite PC-relative branch targets to labels so gas can compute
            # the displacement (objdump prints them as absolute addresses)
            m = re.match(r"(\w+)\s+(.*)", text)
            if m and m.group(1).lower() in REL_OPS:
                tgt = m.group(2).strip()
                if re.fullmatch(r"0x[0-9a-f]+", tgt):
                    tv = int(tgt, 16)
                    if tv in addrs or tv >= start:
                        text = f"{m.group(1)} L_{tv:06x}"
            lines.append("        " + text)
        pos = addr + len(raw)
    if pos < end:
        tail = open(EXE, "rb").read()[pos:end]
        lines.append("        .byte " + ",".join(f"0x{b:02x}" for b in tail))
        pos = end
    # define real labels for branch targets beyond this range: forward .org, then
    # label; the extra section bytes are truncated by the caller (displacements
    # still resolve correctly). .set absolutes DO NOT work for PC-relative ops.
    ext = sorted({int(mm.group(2), 16)
                  for _, _, t in rows
                  if (mm := re.match(r"(\w+)\s+(0x[0-9a-f]+)\s*$", t))
                  and mm.group(1).lower() in REL_OPS
                  and int(mm.group(2), 16) not in addrs
                  and int(mm.group(2), 16) >= start})
    for tv in ext:
        if tv - start > pos - start:
            lines.append(f"        .org {tv - start}")
            lines.append(f"L_{tv:06x}:")
    return "\n".join(lines) + "\n"


def assemble(asm_path, bin_path):
    r = subprocess.run(["as", "--32", "-o", bin_path + ".o", asm_path],
                       capture_output=True, text=True)
    if r.returncode != 0:
        return None, r.stderr
    r2 = subprocess.run(["objcopy", "-j", ".text", "-O", "binary",
                         bin_path + ".o", bin_path],
                        capture_output=True, text=True)
    return (b"" if r2.returncode else open(bin_path, "rb").read()), r2.stderr


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--start", type=lambda x: int(x, 0), required=True)
    ap.add_argument("--end", type=lambda x: int(x, 0), required=True)
    ap.add_argument("--out", required=True)
    a = ap.parse_args()

    rows = objdump_lines(a.start, a.end)
    forced = {ad for ad, _, t in rows if "(bad)" in t}
    orig = open(EXE, "rb").read()[a.start:a.end]
    for attempt in range(3000):
        asm = emit_asm(rows, a.start, a.end, forced)
        with open(a.out, "w") as f:
            f.write(asm)
        out, err = assemble(a.out, "/var/tmp/u2-night-asm.bin")
        if out is None:
            # pick the first error line that maps to an instruction (skip
            # prologue/arch messages); force its row and retry
            with open(a.out) as fh:
                alllines = fh.read().splitlines()
            first_insn = next(i for i, l in enumerate(alllines, 1)
                              if l.startswith("L_"))
            cand = [int(x) for x in re.findall(r":(\d+): [Ee]rror", err)
                    if int(x) >= first_insn]
            fixed = False
            for lineno in sorted(cand):
                addr = None
                cur = None
                for i, l in enumerate(alllines, 1):
                    m2 = re.match(r"L_([0-9a-f]{6}):", l)
                    if m2:
                        cur = int(m2.group(1), 16)
                    if i == lineno:
                        addr = cur
                        break
                if addr is not None and addr not in forced:
                    forced.add(addr)
                    fixed = True
            if not fixed:
                print("ASSEMBLY FAILED, cannot localize:", err[:300])
                sys.exit(1)
            continue
        if len(out) != len(orig):
            out = out[:len(orig)] + b"\x00" * max(0, len(orig) - len(out))
        diffs = [i for i in range(len(orig)) if orig[i] != out[i]]
        if not diffs:
            print(f"BYTE-MATCH: {len(orig)} bytes identical "
                  f"({len(rows)} instructions, {len(forced)} forced to .byte)")
            return 0
        # a byte mismatch without an assembler error: force the instruction
        # covering the first diff
        bad = diffs[0] + a.start
        for ad, raw, text in rows:
            if ad <= bad < ad + len(raw) and ad not in forced:
                forced.add(ad)
                break
        else:
            print(f"UNFIXABLE diff at {bad:#x}; diffs={len(diffs)}")
            return 1
    print(f"gave up after 3000 attempts, forced={len(forced)}")
    return 1


if __name__ == "__main__":
    sys.exit(main())
