#!/usr/bin/env python3
"""Merge contiguous asm/ fragments that the Phase 2 clean wave cut out of one routine.

Usage:
    tools/merge_fragments.py START END [--name newsuffix] [--apply]

START and END are 4-hex RUNTIME addresses (the same form asm/ filenames use, i.e.
file offset - 0x200). The tool merges every function-map row whose start falls in
[START, END] into the row at START.

What a merge is, precisely:
  * the surviving file's body becomes the concatenation of every absorbed file's
    body lines, in start-address order, with NO line edited. Blank lines are kept
    because engine/tests/asm_body_guard.py counts them as body.
  * absorbed files are deleted (git rm).
  * disasm/function-map.tsv gets the surviving row widened to START..END with the
    recomputed length, and the absorbed rows are removed. This is the step that is
    easy to forget and it is not optional: check_func.py validates the body against
    the MAP, so a merged file without a map update fails on length, not on bytes.
  * the surviving header's `# func` line is rewritten and a `# MERGED` line records
    what was absorbed. Header lines are free; body lines are not.

Refuses, with a non-zero exit, when:
  * the rows do not tile [START, END] contiguously (a gap means a fragment has no
    file, or the span is wrong)
  * any label is defined in more than one of the files being joined. That is the
    seam-label collision (clock_int1a, video_int10, ...) and it needs an owner
    ruling, not a workaround. See docs/fragment-splits.md.
  * the assembled body would not be byte-identical. The tool cannot prove that
    itself; it prints the verification commands to run afterwards.

Dry run by default. --apply writes.
"""
from __future__ import annotations

import argparse
import glob
import os
import re
import subprocess
import sys

MAP = "disasm/function-map.tsv"
FUNC_RE = re.compile(r"^#\s*func\s+([0-9A-Fa-f]{4})\.\.([0-9A-Fa-f]{4})\s+len\s+([0-9A-Fa-f]{4})\s+B\b(.*)$")
LABEL_RE = re.compile(r"^([A-Za-z_$.][\w$.]*):")


def die(msg: str) -> "None":
    print(f"merge_fragments: REFUSING: {msg}")
    sys.exit(1)


def body_lines(text: str) -> list[str]:
    """Exactly the rule asm_body_guard uses: every line that is not a comment."""
    return [ln for ln in text.splitlines() if not ln.lstrip().startswith("#")]


def header_lines(text: str) -> list[str]:
    return [ln for ln in text.splitlines() if ln.lstrip().startswith("#")]


def load_map() -> tuple[list[list[str]], str]:
    raw = open(MAP).read().splitlines()
    header = raw[0]
    return [l.split("\t") for l in raw[1:]], header


def main() -> int:
    ap = argparse.ArgumentParser(description="merge contiguous asm/ fragments")
    ap.add_argument("start")
    ap.add_argument("end")
    ap.add_argument("--name", help="new filename suffix for the survivor (no .asm)")
    ap.add_argument("--apply", action="store_true", help="write the changes")
    a = ap.parse_args()

    try:
        S, E = int(a.start, 16), int(a.end, 16)
    except ValueError:
        die("START/END must be 4-hex")
    if len(a.start) != 4 or len(a.end) != 4:
        die("START/END must be exactly 4 hex digits (runtime form)")

    rows, header = load_map()
    span = [r for r in rows if S <= int(r[0], 16) <= E]
    if not span:
        die(f"no function-map rows in {a.start}..{a.end}")

    # 1. contiguity: the rows must tile the span with no gaps and no overlap
    for i, r in enumerate(span):
        want = S if i == 0 else int(span[i - 1][1], 16) + 1
        if int(r[0], 16) != want:
            die(f"rows do not tile: expected start {want:04X}, got {r[0]}")
    if int(span[-1][1], 16) != E:
        die(f"last row ends {span[-1][1]}, not {a.end}")
    total = sum(int(r[2], 16) for r in span)
    if total != E - S + 1:
        die(f"row lengths sum to {total}, span is {E - S + 1}")

    # 2. every row must have exactly one asm file
    files: list[tuple[str, str]] = []
    for r in span:
        g = sorted(glob.glob(f"asm/{r[0]}_*.asm"))
        if len(g) != 1:
            die(f"{r[0]}: expected 1 asm file, found {len(g)}: {g}")
        files.append((r[0], g[0]))

    # 3. no label may be defined twice across the joined set
    seen: dict[str, str] = {}
    dups: dict[str, list[str]] = {}
    for seg, path in files:
        for ln in body_lines(open(path).read()):
            m = LABEL_RE.match(ln)
            if m:
                lbl = m.group(1)
                if lbl in seen:
                    dups.setdefault(lbl, [seen[lbl]]).append(path)
                else:
                    seen[lbl] = path
    if dups:
        for lbl, where in dups.items():
            print(f"  duplicate label `{lbl}:` in {' '.join(where)}")
        die("duplicate labels would collide in one compilation unit. This is the "
            "seam-label case; it needs an owner ruling (docs/fragment-splits.md).")

    # 4. build the merged file
    surv_seg, surv_path = files[0]
    surv_text = open(surv_path).read()
    merged_body: list[str] = []
    for _, path in files:
        merged_body.extend(body_lines(open(path).read()))

    absorbed = [seg for seg, _ in files[1:]]
    new_head: list[str] = []
    note = (f"# MERGED {os.environ.get('MERGE_DATE', '')} from {len(files)} fragments the "
            f"Phase 2/3 wave cut out of one routine: {' '.join(absorbed)}. Body lines are "
            f"concatenated in address order and none was edited; "
            f"engine/tests/asm_body_guard.py requires the tree's assemblable content to be "
            f"conserved, and it is.")
    replaced_func = False
    for ln in header_lines(surv_text):
        m = FUNC_RE.match(ln)
        if m and not replaced_func:
            new_head.append(f"# func {a.start.upper()}..{a.end.upper()}  "
                            f"len {E - S + 1:04X} B{m.group(4)}")
            new_head.append(note)
            replaced_func = True
        else:
            new_head.append(ln)
    if not replaced_func:
        die(f"survivor {surv_path} has no parseable `# func` line")
    if a.name:
        new_path = f"asm/{a.start.upper()}_{a.name}.asm"
    else:
        new_path = surv_path

    print(f"merge {a.start.upper()}..{a.end.upper()}: {len(files)} files -> 1 "
          f"({E - S + 1} bytes, {len(merged_body)} body lines)")
    print(f"  survivor : {surv_path}" + (f" -> {new_path}" if new_path != surv_path else ""))
    print(f"  absorbed : {', '.join(absorbed)}")
    if not a.apply:
        print("\ndry run; nothing written. re-run with --apply")
        return 0

    # 5. write. Order matters: rename FIRST, then overwrite the survivor at its new
    #    path. Writing the new file before `git mv` makes git refuse with
    #    "destination exists", which is how the first version of this tool failed.
    if new_path != surv_path and os.path.exists(new_path):
        die(f"{new_path} already exists; refusing to overwrite")
    if new_path != surv_path:
        subprocess.run(["git", "mv", surv_path, new_path], check=True)
    open(new_path, "w").write("\n".join(new_head) + "\n" + "\n".join(merged_body) + "\n")
    for _, path in files[1:]:
        subprocess.run(["git", "rm", "-q", path], check=True)

    drop = set(absorbed)
    out = []
    for r in rows:
        if r[0] in drop:
            continue
        if r[0] == surv_seg:
            r = [r[0], a.end.upper(), f"{E - S + 1:04X}", r[3],
                 a.name if a.name else r[4]]
        out.append("\t".join(r))
    open(MAP, "w").write(header + "\n" + "\n".join(out) + "\n")
    print(f"  map      : {len(rows)} rows -> {len(out)}")
    print("\nnow verify:")
    print(f"  python3 engine/tests/asm_body_guard.py")
    print(f"  python3 tools/check_func.py {a.start}")
    print(f"  bash tools/assemble_clean.sh")
    return 0


if __name__ == "__main__":
    sys.exit(main())
