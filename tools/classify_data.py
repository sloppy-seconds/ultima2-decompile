#!/usr/bin/env python3
"""Phase 2 CP2: classify every code-segment byte as code or data.

Priority: code-confirmed (executed CFG block byte ranges from all 45 captures)
> psp (0x0000..0x00FF) > table > string > zeros > unclassified.
Emits disasm/data-regions.tsv and disasm/ultimaii-classified.asm (data bytes
as .byte lines, labels preserved), then re-assembles the classified asm and
byte-diffs against original/ (must match). Segment offsets; file = seg + 0x200.
"""
import glob
import json
import re
import subprocess
import sys

SEG_LEN = 0x9000
BIAS = 0x200
EXE = "original/ultimaii.exe"
ASM = "disasm/ultimaii.asm"


def load_seg():
    return open(EXE, "rb").read()[BIAS:]


def code_confirmed():
    bm = bytearray(SEG_LEN)
    paths = ["captures/spice86/spice86-cfg.json"]
    paths += sorted(glob.glob("captures/external-20261019/*/cfg_blocks.json"))
    for p in paths:
        cfg = json.load(open(p))
        by_id = {b["id"]: b for b in cfg["blocks"]}
        for b in cfg["blocks"]:
            seg, off = b["entry"].split(":")
            if seg.upper() != "017D":
                continue
            if b.get("dead"):
                live = [x for x in b.get("pred", [])
                        if x in by_id and not by_id[x].get("dead")]
                if not live:
                    continue
            o = int(off, 16)
            for rec in b.get("asm", []):
                hexb = rec.split("|")[0]
                n = len(hexb) // 2
                if 0 <= o < SEG_LEN:
                    bm[o:o + n] = b"\x01" * n
                o += n
    return bm


def find_regions(seg, bm):
    """Return list of (start, end, kind) covering 0..SEG_LEN-1 (merged, sorted)."""
    kinds = []

    def classify(i):
        if bm[i]:
            return "code"
        if i < 0x100:
            return "psp"
        return None  # undecided

    kind = [classify(i) for i in range(SEG_LEN)]
    # strings: printable runs >= 4
    for m in re.finditer(rb"[\x20-\x7e]{4,}", bytes(seg)):
        for i in range(m.start(), m.end()):
            if kind[i] is None:
                kind[i] = "string"
    # zero runs >= 8
    for m in re.finditer(rb"\x00{8,}", bytes(seg)):
        for i in range(m.start(), m.end()):
            if kind[i] is None:
                kind[i] = "zeros"
    # word tables: >=6 consecutive even-aligned words that are function-map starts
    starts = {int(l.split("\t")[0], 16)
              for l in open("disasm/function-map.tsv").read().splitlines()[1:]}
    i = 0
    while i < SEG_LEN - 12:
        run = 0
        while (i + 2 * (run + 1) <= SEG_LEN and
               int.from_bytes(bytes(seg[i + 2 * run:i + 2 * run + 2]), "little") in starts):
            run += 1
        if run >= 6:
            for j in range(i, i + 2 * run):
                if kind[j] is None:
                    kind[j] = "table"
            i += 2 * run
        else:
            i += 2
    for i in range(SEG_LEN):
        if kind[i] is None:
            kind[i] = "unclassified"
    # bytes inside derived-evidence (call/reko, non-seed) function ranges -> code-derived
    for l in open("disasm/function-map.tsv").read().splitlines()[1:]:
        p = l.split("\t")
        if not p[3].startswith("seed"):
            for i in range(int(p[0], 16), int(p[1], 16) + 1):
                if kind[i] == "unclassified":
                    kind[i] = "code-derived"
    # merge
    out = [(0, 0, kind[0])]
    for i in range(1, SEG_LEN):
        if kind[i] == out[-1][2]:
            out[-1] = (out[-1][0], i, out[-1][2])
        else:
            out.append((i, i, kind[i]))
    return out, kind


def emit_regions(regions):
    with open("disasm/data-regions.tsv", "w") as f:
        f.write("start\tend\tlen\tkind\n")
        for s, e, k in regions:
            if k not in ("code", "code-derived"):
                f.write(f"{s:04X}\t{e:04X}\t{e - s + 1:04X}\t{k}\n")


def classify_asm(kind):
    src = open(ASM).read().splitlines()
    out = []
    lab = re.compile(r"^L_([0-9a-f]{6}):$")
    marks = [(n, int(lab.match(l).group(1), 16))
             for n, l in enumerate(src) if lab.match(l)]
    by_line = {n: j for j, (n, _) in enumerate(marks)}
    skip_to = -1
    for n, line in enumerate(src):
        if n < skip_to:
            continue
        m = lab.match(line)
        if not m:
            out.append(line)
            continue
        out.append(line)
        j = by_line[n]
        seg = int(m.group(1), 16) - BIAS
        if 0 <= seg < SEG_LEN and kind[seg] not in ("code", "code-derived"):
            end_off = marks[j + 1][1] if j + 1 < len(marks) else marks[j][1] + 1
            raw = load_seg()[seg:seg + (end_off - marks[j][1])]
            hexs = ",".join(f"0x{b:02X}" for b in raw)
            out.append(f"        .byte {hexs}  # {kind[seg]}")
            skip_to = marks[j + 1][0] if j + 1 < len(marks) else len(src)
    open("disasm/ultimaii-classified.asm", "w").write("\n".join(out) + "\n")


def forced_explanation(kind):
    tot = {"data-misread": 0, "opcode-artifact": 0, "outside-seg": 0}
    lab = None
    for line in open(ASM):
        m = re.match(r"^L_([0-9a-f]{6}):", line)
        if m:
            lab = int(m.group(1), 16) - BIAS
        if "# forced:" in line:
            if lab is None or not (0 <= lab < SEG_LEN):
                tot["outside-seg"] += 1
            elif kind[lab] not in ("code", "code-derived"):
                tot["data-misread"] += 1
            else:
                tot["opcode-artifact"] += 1
    return tot


def main():
    seg = load_seg()
    bm = code_confirmed()
    regions, kind = find_regions(seg, bm)
    emit_regions(regions)
    classify_asm(kind)
    from collections import Counter
    c = Counter(kind)
    print("byte kinds:", dict(c))
    print("forced .byte explanation:", forced_explanation(kind))
    # verify classified asm
    subprocess.run(["as", "--32", "-o", "/var/tmp/u2-cls.o",
                    "disasm/ultimaii-classified.asm"], check=True)
    subprocess.run(["objcopy", "-j", ".text", "-O", "binary", "/var/tmp/u2-cls.o",
                    "/var/tmp/u2-cls.bin"], check=True)
    orig = open(EXE, "rb").read()
    out = open("/var/tmp/u2-cls.bin", "rb").read()[:len(orig)]
    if orig == out:
        print("CLASSIFIED BYTE-MATCH: OK")
    else:
        print("CLASSIFIED BYTE-MATCH: FAIL",
              sum(1 for a, b in zip(orig, out) if a != b), "bytes differ")
        sys.exit(1)


if __name__ == "__main__":
    sys.exit(main())
