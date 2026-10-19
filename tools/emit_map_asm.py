#!/usr/bin/env python3
"""Phase 2 CP3: map-driven ground-truth asm (aligned per function).

The Phase 1 linear decode mis-aligns at 106 function starts. This tool decodes
EACH function from its own start address (objdump per range), emits data-region
bytes as .byte blobs, and runs the same iterative force-to-.byte loop as
extract_asm.py. Output: disasm/ultimaii-mapped.asm — every function start has
a label, and the file must re-assemble byte-identical.
"""
import re
import sys

sys.path.insert(0, "tools")
from extract_asm import objdump_lines, assemble, REL_OPS  # noqa: E402
import classify_data as cd  # noqa: E402

EXE = "original/ultimaii.exe"
OUT = "disasm/ultimaii-mapped.asm"
DATA_KINDS = ("psp", "string", "zeros", "table")


def load():
    seg = cd.load_seg()
    bm = cd.code_confirmed()
    _, kind = cd.find_regions(seg, bm)
    return seg, kind


def preseed_forced():
    """Addresses forced to .byte in the linear asm (same bytes -> likely again)."""
    f = set()
    lab = None
    for line in open("disasm/ultimaii.asm"):
        m = re.match(r"^L_([0-9a-f]{6}):", line)
        if m:
            lab = int(m.group(1), 16)
        if "# forced:" in line and lab is not None:
            f.add(lab)
    return f


def build(kind, func_rows):
    data = open(EXE, "rb").read()
    lines = ["# map-driven ground-truth asm (per-function aligned)",
             "        .code16", "        .text"]
    # MZ header + PSP as blobs
    lines.append("        .byte " + ",".join(f"0x{b:02x}" for b in data[:cd.BIAS])
                 + "  # mz-header")
    lines.append("        .byte " + ",".join(f"0x{b:02x}" for b in data[cd.BIAS:0x300])
                 + "  # psp")
    for s, e, ev, hint, rows in func_rows:
        fs = int(s, 16) + cd.BIAS
        fe = int(e, 16) + cd.BIAS
        lines.append(f"# func {s}..{e} {ev} {hint}")
        pos = fs
        for addr, raw, text in rows:
            if addr < pos:
                continue
            if addr > pos:  # gap: objdump skipped bytes
                lines.append("        .byte "
                             + ",".join(f"0x{b:02x}" for b in data[pos:addr])
                             + "  # gap-pad")
            if addr + len(raw) > fe + 1:  # straddles into next function
                lines.append(f"L_{addr:06x}:")
                lines.append("        .byte "
                             + ",".join(f"0x{b:02x}" for b in raw[:fe + 1 - addr])
                             + "  # straddle-trunc")
                pos = fe + 1
                break
            lines.append(f"L_{addr:06x}:")
            pos = addr + len(raw)
            seg = addr - cd.BIAS
            if kind[seg] in DATA_KINDS:
                lines.append(f"        .byte {','.join('0x%02x' % b for b in raw)}"
                             f"  # {kind[seg]}")
                continue
            # objdump truncates a row at stop-address but still prints full text;
            # gas would re-encode a PC-rel op LONGER than the bytes present -> force
            mt = re.match(r"(\w+)\s+(0x[0-9a-f]+)\s*$", text)
            if mt and mt.group(1).lower() in REL_OPS:
                need = 2 if abs(int(mt.group(2), 16) - (addr + 2)) <= 127 else 3
                if len(raw) < need:
                    lines.append(f"        .byte {','.join('0x%02x' % b for b in raw)}"
                                 f"  # forced: stop-trunc {text}")
                    continue
            if addr in FORCED:
                lines.append(f"        .byte {','.join('0x%02x' % b for b in raw)}"
                             f"  # forced: {text}")
                continue
            m = re.match(r"(\w+)\s+(.*)", text)
            if m and m.group(1).lower() in REL_OPS:
                tgt = m.group(2).strip()
                if re.fullmatch(r"0x[0-9a-f]+", tgt):
                    lines.append(f"        {m.group(1)} L_{int(tgt, 16):06x}")
                    continue
            lines.append("        " + text)
        if pos <= fe:  # tail bytes not covered by any row
            tail = data[pos:fe + 1]
            lines.append("        .byte " + ",".join(f"0x{b:02x}" for b in tail)
                         + "  # tail-pad")
    return lines


FORCED = preseed_forced()


def main():
    seg, kind = load()
    func_rows = []
    for l in open("disasm/function-map.tsv").read().splitlines()[1:]:
        s, e, ln, ev, hint = l.split("\t")
        fs, fe = int(s, 16) + cd.BIAS, int(e, 16) + cd.BIAS
        func_rows.append((s, e, ev, hint, objdump_lines(fs, fe + 1)))
    print(f"objdump pass done ({len(func_rows)} functions)", flush=True)
    orig = open(EXE, "rb").read()
    for attempt in range(4000):
        lines = build(kind, func_rows)
        open(OUT, "w").write("\n".join(lines) + "\n")
        out, err = assemble(OUT, "/var/tmp/u2-mapped.bin")
        if out is None:
            alllines = open(OUT).read().splitlines()
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
                if addr is not None and addr not in FORCED:
                    FORCED.add(addr)
                    fixed = True
            if not fixed:
                print("ASSEMBLY FAILED, cannot localize:", err[:300])
                return 1
            continue
        out = out[:len(orig)] + b"\x00" * max(0, len(orig) - len(out))
        diffs = [i for i in range(len(orig)) if orig[i] != out[i]]
        if not diffs:
            print(f"MAPPED BYTE-MATCH: {len(orig)} bytes identical "
                  f"({len(FORCED)} forced)")
            return 0
        bad = diffs[0]
        labels = []
        for l in open(OUT):
            m2 = re.match(r"L_([0-9a-f]{6}):", l)
            if m2 and int(m2.group(1), 16) <= bad:
                labels.append(int(m2.group(1), 16))
        cand = [a for a in reversed(labels) if a not in FORCED]
        if not cand:
            print(f"UNFIXABLE diff at {bad:#x}")
            return 1
        FORCED.add(cand[0])
    print("gave up")
    return 1


if __name__ == "__main__":
    sys.exit(main())
