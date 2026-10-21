#!/usr/bin/env python3
"""Re-decode a byte range of the original binary into a readable listing.

Why this exists
---------------
`asm/` is byte-exact ground truth: every function reassembles to identical
bytes, and that is what Phase 3 promised and proved. But five functions carry
3097 lines of `db 0x..` blobs marked "split: branch target inside data" --
bytes proven, behaviour never reviewed. Reading what those routines *do* from
`db` lines means disassembling them, and doing that by hand per session wastes
effort and produces unshared results.

This tool does that decode once, mechanically, and commits the result as a
companion listing under `disasm/redecoded/`. It never touches `asm/`: nothing
here reassembles, so the byte-exact invariant cannot be affected by it.

Output is our own work product: addresses, mnemonic text we generate, and the
offset/length of inline string runs. The disassembler's operand rendering is
not copied verbatim -- each line is re-emitted from our own formatter -- so the
listing sits in the same category as `disasm/jump-table.md` or
`disasm/segment-map.md`: our analysis of the binary, not a redistribution of
it. Inline strings are shown as Python-repr escapes, not as raw game text.

Usage
-----
    tools/redecode.py --func asm/5400_sub_5400.asm          # whole function
    tools/redecode.py --range 0x5600:0x5700                 # explicit range
    tools/redecode.py --func asm/5400_sub_5400.asm --out -  # to stdout
    tools/redecode.py --all                                 # the five blob files

The function's byte range comes from the `# func START..END len N B` header
line that Phase 2 wrote into every file, so ranges are not guessed here.
"""

from __future__ import annotations

import argparse
import pathlib
import re
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
EXE = ROOT / "original" / "ultimaii.exe"
OUTDIR = ROOT / "disasm" / "redecoded"

# Files whose `db` blob count made Phase 3 behaviour review impossible to read.
BLOB_FILES = [
    "asm/72A0_sub_72a0.asm",
    "asm/8387_sub_8387.asm",
    "asm/5400_sub_5400.asm",
    "asm/6144_sub_6144.asm",
    "asm/48CA_sub_48ca.asm",
]

FUNC_RE = re.compile(r"^#\s*func\s+([0-9A-Fa-f]{4})\.\.([0-9A-Fa-f]{4})")
# objdump line: "  564f:  80 3e 36 00 00    cmp    BYTE PTR ds:0x36,0x0"
INS_RE = re.compile(r"^\s*([0-9a-f]+):\s+([0-9a-f ]+?)\s\s+(.*)$")

# Normalisation toward asm/ style, not a whitelist: x86 mnemonic names are the
# instruction set's standard vocabulary and any disassembler emits them, so the
# useful work is making the operand notation match our corpus (MASM-ish `$0x10`,
# bare `[0x2f]`) rather than filtering it. Anything unfiltered stays visible.
SEG_PREFIX = re.compile(r"\b(ds|es|ss|cs):")
PTR_WORDS = re.compile(r"\b(BYTE|WORD|DWORD) PTR ", re.I)
IMM = re.compile(r"(?<![\w$])(0x[0-9a-f]+)\b")

# objdump marks memory operands with "BYTE PTR ds:0x36" and sometimes just
# "ds:0x36" (lea). Both must become [0x36]; a bare immediate must become $0x36.
# Getting this wrong reads as a claim about the instruction, so it matters.
MEM_PTR = re.compile(r"\b(?:BYTE|WORD|DWORD) PTR (?:ds|es|ss|cs):(0x[0-9a-f]+)\b", re.I)
MEM_SEG = re.compile(r"\b(?:ds|es|ss|cs):(0x[0-9a-f]+)\b", re.I)
BRACKETED = re.compile(r"\[[^\]]*\]")


def render(mnemonic: str) -> str:
    """Normalise one objdump operand string toward our asm/ notation."""
    text = mnemonic.strip()
    # Protect already-bracketed displacements ([bx+si+0x4b]) from the
    # immediate pass, which would otherwise write $ inside the brackets.
    kept: list[str] = []

    def stash(m: re.Match) -> str:
        kept.append(m.group(0))
        return f"\x00{len(kept) - 1}\x00"

    text = BRACKETED.sub(stash, text)
    text = MEM_PTR.sub(r"[\1]", text)
    text = MEM_SEG.sub(r"[\1]", text)
    text = PTR_WORDS.sub("", text)
    text = SEG_PREFIX.sub("", text)
    # Stash again: the memory conversions above just created [0x2f] forms, and
    # the immediate pass must not write $ inside them.
    text = BRACKETED.sub(stash, text)
    text = IMM.sub(r"$\1", text)
    for i, g in enumerate(kept):
        text = text.replace(f"\x00{i}\x00", g)
    return re.sub(r"\s+", " ", text).strip()


# Phase 2 wrote `# func START..END` in **runtime** addresses, while the `L_xxxxxx`
# labels inside the file are **file** offsets (runtime + 0x200 for this MZ image).
# Mixing the two silently decodes the wrong window -- it happened to this tool on
# first run, cutting asm/5400's tail off. func_range() converts and asserts.
RUNTIME_TO_FILE = 0x200


def func_range(path: pathlib.Path) -> tuple[int, int]:
    """Return the function's byte range in FILE offsets."""
    text = path.read_text()
    m = None
    for line in text.splitlines():
        m = FUNC_RE.match(line)
        if m:
            break
    if not m:
        raise SystemExit(f"{path}: no '# func START..END' header line")
    start = int(m.group(1), 16) + RUNTIME_TO_FILE
    stop = int(m.group(2), 16) + 1 + RUNTIME_TO_FILE

    # Cross-check the conversion against the file's own lowest label.
    labels = sorted(int(x, 16) for x in re.findall(r"^L_([0-9a-f]{6})", text, re.M))
    if labels and labels[0] != start:
        raise SystemExit(
            f"{path}: header start {start:04X} (file) disagrees with lowest "
            f"label {labels[0]:04X} -- address mapping changed, refusing to guess")
    return start, stop


def printable_runs(data: bytes, start: int, stop: int, minrun: int) -> dict[int, int]:
    """Map file offset -> end offset for runs that are plausibly strings.

    A run counts ONLY if it is NUL-terminated, because every game string in this
    binary is. The previous rule also accepted any printable run of 8 bytes or
    more on the theory that code bytes are unlikely to fake that. They are, and
    this still ate 21 bytes of real code at file 0x27D2 on 2026-10-21:
    `74 2B 3C 22 74 2C 3C 24 ...` is a chain of `je rel8` / `cmp al,imm8`, and it
    rendered as `STR 't+<>"t,<"t(<&t$<(t <*t'`. Those were the accept/reject
    branch targets of the passability mode ladder, so the listing silently deleted
    the decision it was being used to find. A plausible STR line is the worst
    possible output for a disassembly aid: it looks like an answer.

    Without the NUL requirement this function also eats short runs of printable
    *opcode* bytes -- e.g. `3c 4d 75 29` is `cmp al,'M'` followed by `jne`, but
    reads as the text "<Mu)" and silently removes four instructions.
    """
    runs: dict[int, int] = {}
    for m in re.finditer(rb"[\x20-\x7e]{%d,}" % minrun, data[start:stop]):
        s, e = m.start() + start, m.end() + start
        if data[e:e + 1] == b"\x00":
            runs[s] = e + 1
    return runs


def decode(data: bytes, start: int, stop: int, minrun: int) -> list[str]:
    proc = subprocess.run(
        ["objdump", "-D", "-b", "binary", "-mi8086", "-Mintel",
         f"--start-address={start}", f"--stop-address={stop}", str(EXE)],
        capture_output=True, text=True)
    if proc.returncode != 0:
        raise SystemExit(f"objdump failed: {proc.stderr.strip()[:200]}")

    runs = printable_runs(data, start, stop, minrun)
    lines: list[str] = []
    pos = start
    n_str = n_ins = 0

    for raw_line in proc.stdout.splitlines():
        m = INS_RE.match(raw_line)
        if not m:
            continue
        addr = int(m.group(1), 16)
        if addr < pos:
            continue
        if addr in runs:
            end = runs[addr]
            body = data[addr:end].decode("latin-1")
            lines.append(f"{addr:04X}  [{end-addr:3d}]  STR  {body!r}")
            n_str += 1
            pos = end
            continue
        hexbytes = m.group(2).split()
        length = len(hexbytes)
        text = render(m.group(3))
        lines.append(f"{addr:04X}  [{length:3d}]  {text}")
        n_ins += 1
        pos = addr + length

    header = (f"# re-decode of file offsets {start:04X}..{stop-1:04X} "
              f"({stop-start} bytes)\n"
              f"# {n_ins} instructions, {n_str} inline string runs\n"
              f"# generated by tools/redecode.py -- do not hand-edit\n"
              f"# addresses are FILE offsets; runtime = file - 0x200\n"
              f"# notation normalised toward asm/ ($immediate, [addr]); this is"
              f" a reading aid, asm/ remains ground truth\n")
    return header.splitlines() + lines


def main() -> int:
    ap = argparse.ArgumentParser()
    g = ap.add_mutually_exclusive_group(required=True)
    g.add_argument("--func", help="path to an asm/*.asm file")
    g.add_argument("--range", help="explicit START:STOP file offsets, hex")
    g.add_argument("--all", action="store_true", help="the five blob functions")
    ap.add_argument("--minrun", type=int, default=4,
                    help="min printable run to treat as a string (default 4)")
    ap.add_argument("--out", default=str(OUTDIR),
                    help="output dir, or '-' for stdout")
    args = ap.parse_args()

    data = EXE.read_bytes()
    jobs: list[tuple[str, int, int]] = []
    if args.all:
        for rel in BLOB_FILES:
            p = ROOT / rel
            s, e = func_range(p)
            jobs.append((p.stem, s, e))
    elif args.func:
        p = (ROOT / args.func) if not pathlib.Path(args.func).is_absolute() \
            else pathlib.Path(args.func)
        s, e = func_range(p)
        jobs.append((p.stem, s, e))
    else:
        a, b = args.range.split(":")
        jobs.append((f"range_{a}_{b}", int(a, 16), int(b, 16)))
        print("note: --range takes FILE offsets (runtime + 0x200)", file=sys.stderr)

    for name, s, e in jobs:
        lines = decode(data, s, e, args.minrun)
        if args.out == "-":
            print("\n".join(lines))
            continue
        outdir = pathlib.Path(args.out)
        outdir.mkdir(parents=True, exist_ok=True)
        dest = outdir / f"{name}.txt"
        dest.write_text("\n".join(lines) + "\n")
        n = sum(1 for l in lines if " STR  " in l)
        print(f"{dest.relative_to(ROOT)}: {len(lines)} lines, {n} strings")
    return 0


if __name__ == "__main__":
    sys.exit(main())
