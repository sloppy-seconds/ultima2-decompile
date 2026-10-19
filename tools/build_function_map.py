#!/usr/bin/env python3
"""Phase 2 CP1: build the function boundary map over the code segment.

Space: SEGMENT offsets (0x0000..0x8FFF); file = seg + 0x200 (see plan §1).
Starts (evidence, in priority order recorded per start):
  seed      - disasm/seed-entries.txt (execution-confirmed or jump-table)
  call      - call/lcall targets found in disasm/ultimaii.asm (file labels -> seg)
  reko      - procedure defines in decompiled/reko/ultimaii.c (corroborating)
Functions tile the segment: each start ends at next_start-1; the last ends at
0x8FFF. Bytes before the first start are an unassigned region (CP2 input).
Fails loudly on overlap/gap/coverage errors. Deterministic output.
"""
import re
import sys

SEEDS = "disasm/seed-entries.txt"
ASM = "disasm/ultimaii.asm"
REKO = "decompiled/reko/ultimaii.c"
OUT = "disasm/function-map.tsv"
UNASSIGNED = "disasm/unassigned-regions.tsv"
SEG_END = 0x8FFF
FILE_BIAS = 0x200


def main():
    starts = {}  # seg -> set of evidence tags

    def add(seg, ev):
        if 0 <= seg <= SEG_END:
            starts.setdefault(seg, set()).add(ev)

    for line in open(SEEDS):
        add(int(line.split()[0], 16), "seed")

    n_call = 0
    for line in open(ASM):
        m = re.search(r"\b(?:call|lcall)\s+(?:\$0x[0-9a-f]+,)?L_([0-9a-f]{6})", line)
        if not m:
            m = re.search(r"# forced: (?:call|lcall)\s+0x([0-9a-f]+)", line)
        if m:
            tgt = int(m.group(1), 16) - FILE_BIAS
            if tgt not in starts or "seed" not in starts.get(tgt, set()):
                n_call += 1
            add(tgt, "call")
    for m in re.finditer(r"^define fn0800_([0-9a-fA-F]{4})$", open(REKO).read(), re.M):
        add(int(m.group(1), 16), "reko")

    ordered = sorted(starts)
    # handler name hints from jump-table.txt (seg offsets, letters A-Z in table order)
    hints = {}
    for i, line in enumerate(open("disasm/jump-table.txt")):
        p = line.split()
        hints[int(p[0], 16)] = f"cmd_{chr(65 + i)}"
    hints[0x4FDF] = "str_out"  # shared inline-string display routine (file 0x51DF)

    rows = []
    for i, s in enumerate(ordered):
        e = (ordered[i + 1] - 1) if i + 1 < len(ordered) else SEG_END
        ev = starts[s]
        tag = "+".join(t for t in ("seed", "call", "reko") if t in ev)
        rows.append((s, e, tag, hints.get(s, "")))

    # invariants
    seeds = {int(l.split()[0], 16) for l in open(SEEDS)}
    assert seeds <= set(ordered), "seed missing from starts"
    total = sum(e - s + 1 for s, e, _, _ in rows)
    pre = ordered[0]  # bytes 0x0..ordered[0]-1 unassigned
    assert total + pre == SEG_END + 1, f"coverage error: {total}+{pre}"
    for a, b in zip(rows, rows[1:]):
        assert a[1] + 1 == b[0], "gap/overlap"

    with open(OUT, "w") as f:
        f.write("start\tend\tlen\tevidence\tname_hint\n")
        for s, e, tag, h in rows:
            f.write(f"{s:04X}\t{e:04X}\t{e - s + 1:04X}\t{tag}\t{h}\n")
    with open(UNASSIGNED, "w") as f:
        f.write("start\tend\tlen\n")
        if pre:
            f.write(f"0000\t{pre - 1:04X}\t{pre:04X}\n")
    from collections import Counter
    print(f"functions: {len(rows)}  unassigned-before-first: {pre} B")
    print("evidence mix:", dict(Counter(t for _, _, t, _ in rows)))
    print("call targets added beyond seeds:", n_call)
    print("named:", sum(1 for r in rows if r[3]))
    print(f"-> {OUT}, {UNASSIGNED}")


if __name__ == "__main__":
    sys.exit(main())
