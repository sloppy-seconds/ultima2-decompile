#!/usr/bin/env python3
"""Phase 3 CP1: per-function byte-proof harness.

Usage: tools/check_func.py <SEG> [--file PATH] [-v]

<SEG> is the 4-hex function START from disasm/function-map.tsv (segment offset;
file offset = SEG + 0x200).

Source resolution:
  1. asm/<SEG>_<name>.asm  (cleaned file, if present — exactly one expected)
  2. disasm/functions/<SEG>.asm  (mechanical Phase 2 slice — fallback/baseline)

The source is assembled IN ISOLATION: wrapped with the standard context
(.code16/.text), .org'd to its true file origin, and out-of-function branch
targets (undefined L_<6hex-file-offset> labels) are stubbed with zero-byte
`.org` labels at their real addresses so PC-relative operands encode correctly.

Exit 0 = the assembled bytes in [start, end] are identical to original/.
Also verifies the body length matches the function-map range exactly.
"""
import argparse
import glob
import os
import re
import subprocess
import sys

EXE = "original/ultimaii.exe"
MAP = "disasm/function-map.tsv"
BIAS = 0x200
LABEL_DEF = re.compile(r"^([A-Za-z_$.][\w$.]*):")
LABEL_REF = re.compile(r"\bL_([0-9a-fA-F]{6})\b")


def die(msg):
    print(f"check_func: ERROR: {msg}")
    sys.exit(2)


def load_func(seg4):
    for line in open(MAP).read().splitlines()[1:]:
        s, e, ln, ev, hint = line.split("\t")
        if s.upper() == seg4.upper():
            return int(s, 16), int(e, 16), ev, hint
    die(f"{seg4} is not a function start in {MAP}")


def resolve_source(seg4, explicit):
    if explicit:
        if not os.path.isfile(explicit):
            die(f"--file {explicit} not found")
        return explicit
    cands = sorted(glob.glob(f"asm/{seg4}_*.asm"))
    if len(cands) > 1:
        die(f"multiple cleaned files for {seg4}: {cands}")
    if cands:
        return cands[0]
    mech = f"disasm/functions/{seg4}.asm"
    if os.path.isfile(mech):
        return mech
    die(f"no source: neither asm/{seg4}_*.asm nor {mech}")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("seg")
    ap.add_argument("--file")
    ap.add_argument("-v", action="store_true")
    a = ap.parse_args()
    seg4 = a.seg.upper().removeprefix("0X")
    if not re.fullmatch(r"[0-9A-F]{4}", seg4):
        die(f"<SEG> must be 4 hex digits, got {a.seg!r}")

    fs, fe, ev, hint = load_func(seg4)
    src = resolve_source(seg4, a.file)
    orig = open(EXE, "rb").read()
    sfs, sfe = fs + BIAS, fe + BIAS
    if sfe >= len(orig):
        # last function 8DCD: map range extends past EOF (segment padded to 0x9000,
        # file ends at 0x91E0); clamp to real bytes — assemble_all does the same.
        sfe = len(orig) - 1
    length = sfe - sfs + 1

    body = open(src).read()
    # Cleaned dialect uses MASM-style db/dw (plan CP1); gas needs .byte/.word,
    # and gas .byte takes only 1-char strings — expand multi-char strings to
    # hex byte lists. Mechanical slices already comply. CP5 reuses this rule.
    body = re.sub(r"(?m)^(\s*)dw\b", r"\1.word", body)

    def _split_outside_quotes(s):
        items, cur, inq, esc = [], "", False, False
        for ch in s:
            if esc:
                cur += ch
                esc = False
            elif inq and ch == "\\":
                cur += ch
                esc = True
            elif ch == '"':
                inq = not inq
                cur += ch
            elif ch == "," and not inq:
                items.append(cur)
                cur = ""
            else:
                cur += ch
        items.append(cur)
        return items

    def _str_to_hex(it):
        raw, i, bs = it[1:-1], 0, []
        while i < len(raw):
            if raw[i] == "\\" and i + 1 < len(raw):
                c = raw[i + 1]
                bs.append({"n": 10, "t": 9, "r": 13, "0": 0, '"': 34,
                           "\\": 92}.get(c, ord(c)))
                i += 2
            else:
                bs.append(raw[i] if ord(raw[i]) < 256 else "?")
                i += 1
        return ",".join(f"0x{ord(b):02x}" for b in bs)

    def _split_comment(rest):
        """Split trailing '#...' comment (outside quotes) from operand text."""
        inq, esc = False, False
        for idx, ch in enumerate(rest):
            if esc:
                esc = False
            elif inq and ch == "\\":
                esc = True
            elif ch == '"':
                inq = not inq
            elif ch == "#" and not inq:
                return rest[:idx], rest[idx:]
        return rest, ""

    fixed = []
    for line in body.splitlines():
        m = re.match(r"^(\s*)(db|\.byte)\s+(.*)$", line)
        if not m:
            fixed.append(line)
            continue
        ind, code, comment = m.group(1), *_split_comment(m.group(3))
        items = _split_outside_quotes(code)
        hexs = []
        for it in items:
            it = it.strip()
            if not it:
                continue
            if it.startswith('"') and it.endswith('"') and len(it) >= 2:
                hexs.append(_str_to_hex(it))
            else:
                hexs.append(it)
        cmt = ("  " + comment) if comment else ""
        fixed.append(f"{ind}.byte {','.join(hexs)}{cmt}" if hexs
                     else f"{ind}{comment.strip()}".rstrip())
    body = "\n".join(fixed)
    defined = set()
    for line in body.splitlines():
        m = LABEL_DEF.match(line)
        if m:
            defined.add(m.group(1))
    refs = {}
    for m in LABEL_REF.finditer(body):
        refs[m.group(0)] = int(m.group(1), 16)
    externals = {n: v for n, v in refs.items() if n not in defined}
    for n, t in externals.items():
        if sfs <= t <= sfe:
            die(f"{n} targets inside the function range but is not defined in {src}")

    # assemble in isolation
    work = f"tmp/check/{seg4}"
    os.makedirs(work, exist_ok=True)
    parts = [".code16", ".text"]
    below = sorted((t, n) for n, t in externals.items() if t < sfs)
    above = sorted((t, n) for n, t in externals.items() if t > sfe)
    for t, n in below:  # .org only moves forward; stubs below go first
        parts.append(f".org 0x{t:x}")
        parts.append(f"{n}:")
    parts.append(f".org 0x{sfs:x}")
    parts.append(f"__u2_func_start = 0x{sfs:x}")
    parts.append(body)
    parts.append("__u2_body_end:")
    for t, n in above:  # stubs above the body go after it (counter already past fs)
        parts.append(f".org 0x{t:x}")
        parts.append(f"{n}:")
    sfile = f"{work}/check.s"
    open(sfile, "w").write("\n".join(parts) + "\n")

    r = subprocess.run(["as", "--32", "-o", f"{work}/check.o", sfile],
                       capture_output=True, text=True)
    if r.returncode != 0:
        print(f"check_func: ASSEMBLY FAILED for {src}")
        print(r.stderr.strip()[:4000])
        sys.exit(1)

    # body length must match the map range exactly
    nm = subprocess.run(["nm", f"{work}/check.o"], capture_output=True, text=True).stdout
    m = re.search(r"([0-9a-f]{8}) [tTbBdD] __u2_body_end", nm)
    if not m:
        die("body-end symbol not found in object")
    body_len = int(m.group(1), 16) - sfs
    if body_len != length:
        print(f"check_func: LENGTH MISMATCH {seg4}: body assembled {body_len} B, "
              f"map says {length} B ({src})")
        sys.exit(1)

    subprocess.run(["objcopy", "-j", ".text", "-O", "binary",
                    f"{work}/check.o", f"{work}/check.bin"], check=True)
    out = open(f"{work}/check.bin", "rb").read()
    mine = out[sfs:sfe + 1]
    if len(mine) < length:
        die(f"output shorter than function range")
    if mine == orig[sfs:sfe + 1]:
        print(f"PASS {seg4} {hint or 'sub_' + seg4.lower()} "
              f"[{length} B] src={src}")
        if a.v:
            print(f"  map: {fs:04X}..{fe:04X} evidence={ev} externals={sorted(externals)}")
        sys.exit(0)
    diffs = [(i, o, m2) for i, (o, m2) in enumerate(zip(orig[sfs:sfe + 1], mine))
             if o != m2]
    print(f"FAIL {seg4} [{length} B] src={src} — {len(diffs)} bytes differ")
    for i, o, m2 in diffs[:20]:
        print(f"  +0x{i:04x}: orig {o:02x} != built {m2:02x}")
    if len(diffs) > 20:
        print(f"  ... {len(diffs) - 20} more")
    sys.exit(1)


if __name__ == "__main__":
    main()
