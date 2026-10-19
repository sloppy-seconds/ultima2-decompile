#!/usr/bin/env python3
"""Phase 2 CP3: split the classified asm into one slice per function.

Slice = label line + instruction lines up to the next label. Named by SEGMENT
offset (matches all disasm artifacts). A prologue file holds everything before
the first function (MZ header + PSP region). tools/assemble_all.sh rebuilds.
"""
import os
import re

ASM = "disasm/ultimaii-mapped.asm"
MAP = "disasm/function-map.tsv"
OUT = "disasm/functions"
BIAS = 0x200


def main():
    src = open(ASM).read().splitlines()
    lab = re.compile(r"^L_([0-9a-f]{6}):$")
    marks = [(n, int(lab.match(l).group(1), 16)) for n, l in enumerate(src) if lab.match(l)]
    by_off = {off: j for j, (_, off) in enumerate(marks)}
    os.makedirs(OUT, exist_ok=True)
    starts = [int(l.split("\t")[0], 16) for l in open(MAP).read().splitlines()[1:]]
    n = 0
    for k, seg in enumerate(starts):
        j = by_off[seg + BIAS]
        end = (marks[by_off[starts[k + 1] + BIAS]][0]
               if k + 1 < len(starts) else len(src))
        with open(f"{OUT}/{seg:04X}.asm", "w") as f:
            f.write("\n".join(src[marks[j][0]:end]) + "\n")
        n += 1
    # prologue: file start .. first function label
    with open(f"{OUT}/_prologue.asm", "w") as f:
        f.write("\n".join(src[:marks[by_off[starts[0] + BIAS]][0]]) + "\n")
    print(f"slices: {n} (+ _prologue) -> {OUT}/")


if __name__ == "__main__":
    main()
