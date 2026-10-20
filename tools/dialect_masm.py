#!/usr/bin/env python3
"""Phase 3 CP5: transpile cleaned GNU-as (AT&T) files to MASM dialect and
verify DUAL byte-match (GNU as via check_func + jwasm) per function.

Usage: tools/dialect_masm.py <SEG> [<SEG> ...] [--sample N]

Conversion rules (documented in docs/asm-style.md CP5 addendum):
  * `#` comments kept as `;` (MASM comment)
  * labels unchanged; entry scaffolding: .MODEL TINY / .CODE / ORG <file_start>
  * externals stubbed with ORG+label (same trick as check_func.py)
  * db/dw pass through (already MASM); .byte->db, .word->dw
  * AT&T `op src,dst` -> MASM `op dst,src` for the i8086 two-operand set;
    $imm->immh, %reg->reg, size suffix b/w -> ptr override only when needed
Honesty rule: any instruction the transpiler cannot map makes the function
report CONVERT-FAIL (never a silent approximation).
"""
import glob
import os
import re
import subprocess
import sys
import tempfile

BIAS = 0x200
REL = {"call", "jmp", "je", "jne", "ja", "jae", "jb", "jbe", "jg", "jge",
       "jl", "jle", "jo", "jno", "js", "jns", "jc", "jnc", "loop"}
TWO = {"mov", "cmp", "add", "adc", "sub", "sbb", "and", "or",
       "xor", "test", "push", "pop", "rcl", "rcr", "rol", "ror", "shl", "shr",
       "sar", "xchg", "in", "out", "lea"}
ONE = {"inc", "dec", "not", "neg", "mul", "imul", "div", "idiv",
       "push", "pop", "call", "jmp"}
NOOP = {"clc", "stc", "cmc", "cld", "std", "nop", "ret", "daa", "das", "aaa",
        "aas", "cbw", "cwd", "hlt", "wait", "pushf", "popf", "pusha", "popa",
        "iret", "intov", "sti", "cli"}
REGS = {"al", "ah", "bl", "bh", "cl", "ch", "dl", "dh", "ax", "bx", "cx", "dx",
        "si", "di", "bp", "sp", "cs", "ds", "ss", "es", "ip", "f"}


def att_operand(op, size_hint):
    """AT&T operand -> MASM text. Returns None if unmappable."""
    o = op.strip()
    m = re.fullmatch(r"\$(-?0x[0-9a-f]+|\d+)", o)
    if m:
        v = m.group(1)
        neg = v.startswith("-")
        v = v.lstrip("-")
        return ("-" if neg else "") + \
            (f"0{v[2:]}h" if v.startswith("0x") else v)
    m = re.fullmatch(r"%(\w+)", o)
    if m and m.group(1) in REGS:
        return m.group(1)
    m = re.fullmatch(r"%?(\w+):(-?0x[0-9a-f]+)\((%?\w+)(?:,(%?\w+))?\)", o)
    if m and m.group(1) in REGS:
        seg, disp, b1, b2 = m.groups()
        idx = "+".join(x.lstrip("%") for x in (b1, b2) if x)
        d = disp.lstrip("-")
        d = ("-" if disp.startswith("-") else "") + f"0{d[2:]}h"
        sfx = ("+" + d if not d.startswith("-") else d) \
            if d not in ("0", "-0") else ""
        return f"{seg}:[{idx}{sfx}]"
    m = re.fullmatch(r"(-?0x[0-9a-f]+)\((%?\w+)(?:,(%?\w+))?\)", o)
    if m:
        disp, b1, b2 = m.groups()
        idx = "+".join(x.lstrip("%") for x in (b1, b2) if x)
        d = disp.lstrip("-")
        d = ("-" if disp.startswith("-") else "") + f"0{d[2:]}h"
        sfx = ("+" + d if not d.startswith("-") else d) \
            if d not in ("0", "-0") else ""
        return f"[{idx}{sfx}]"
    m = re.fullmatch(r"%(\w+):(-?0x[0-9a-f]+)", o)
    if m and m.group(1) in REGS:
        seg, disp = m.groups()
        d = disp.lstrip("-")
        return f"{seg}:[{'-' if disp.startswith('-') else ''}0{d[2:]}h]"
    m = re.fullmatch(r"\((%?\w+)(?:,(%?\w+))?\)", o)
    if m:
        b1, b2 = m.groups()
        idx = "+".join(x.lstrip("%") for x in (b1, b2) if x)
        return f"[{idx}]"
    m = re.fullmatch(r"(-?0x[0-9a-f]+)", o)
    if m:  # absolute disp — jwasm quirk: bare [num] encodes as IMMEDIATE,
           # must emit ds:[num] (documented in CP5 log)
        disp = m.group(1)
        d = disp.lstrip("-")
        return ("-" if disp.startswith("-") else "") + f"ds:[0{d[2:]}h]"
    if o.startswith(("L_", "LC_", ".L")):
        return o
    m = re.fullmatch(r"%(\w+):\((%?\w+)(?:,(%?\w+))?\)", o)
    if m and m.group(1) in REGS:
        seg, b1, b2 = m.groups()
        idx = "+".join(x.lstrip("%") for x in (b1, b2) if x)
        return f"{seg}:[{idx}]"
    return None


def split_operands(s):
    parts, cur, depth, inq, esc = [], "", 0, False, False
    for ch in s:
        if esc:
            cur += ch
            esc = False
            continue
        if inq and ch == "\\":
            cur += ch
            esc = True
            continue
        if ch == '"':
            inq = not inq
        elif ch == "(" and not inq:
            depth += 1
        elif ch == ")" and not inq:
            depth -= 1
        if ch == "," and depth == 0 and not inq:
            parts.append(cur)
            cur = ""
        else:
            cur += ch
    parts.append(cur)
    return [p.strip() for p in parts]


def hex_item(it):
    it = it.strip()
    m = re.fullmatch(r"0x([0-9a-fA-F]+)", it)
    if m:
        return f"0{m.group(1)}h"
    return it


def wrap_masm(line, limit=240):
    """jwasm has a line-length limit; split long db/dw hex lists across lines."""
    if len(line) <= limit:
        return line
    m = re.match(r"^(\s*)(d[bw])\s+(.*?)(  ; .*)?$", line)
    if not m:
        return line
    ind, op, items, cmt = m.groups()
    out = []
    cur = ind + op + " "
    for it in items.split(","):
        if len(cur) + len(it) + 1 > limit - 8:
            out.append(cur.rstrip(", "))
            cur = ind + op + " "
        cur += it + ","
    out.append((cur.rstrip(",") + (cmt or "")).rstrip())
    return "\n".join(out)


def split_comment(t):
    """Split trailing '#...' comment outside quotes (game strings contain #)."""
    inq, esc = False, False
    for i, ch in enumerate(t):
        if esc:
            esc = False
        elif inq and ch == "\\":
            esc = True
        elif ch == '"':
            inq = not inq
        elif ch == "#" and not inq:
            return t[:i].rstrip(), "  ; " + t[i + 1:].strip()
    return t, ""


def convert_line(ln):
    """One instruction line -> MASM text, or None if unmappable."""
    t = ln.strip()
    code, comment = split_comment(t)
    if not code:
        return None
    m = re.fullmatch(r"(\.byte|db)\s+(.*)", code)
    if m:
        items = split_operands(m.group(2))
        line = "        db " + ",".join(hex_item(i) for i in items) + comment
        return wrap_masm(line)
    m = re.fullmatch(r"(\.word|dw)\s+(.*)", code)
    if m:
        items = split_operands(m.group(2))
        line = "        dw " + ",".join(hex_item(i) for i in items) + comment
        return wrap_masm(line)
    code = code.split("#", 1)[0].strip()
    if not code:
        return None
    m = re.fullmatch(r"(\w+)\s*$", code)
    if m and m.group(1) in NOOP:
        return "        " + m.group(1) + comment
    m = re.fullmatch(r"(int)\s+\$0x([0-9a-f]+)", code)
    if m:
        return f"        int 0{m.group(2)}h" + comment
    m = re.fullmatch(r"(\w+)\s+(.*)", code)
    if not m:
        return None
    op, rest = m.groups()
    size = ""
    if op in ("jmp", "call") and rest.startswith("*"):
        r = att_operand(rest[1:], op)
        return f"        {op} {r}" if r else None
    base = op
    if op not in REL and op not in TWO | ONE | NOOP and op[-1:] in ("b", "w") \
            and op[:-1] in TWO | ONE | NOOP:
        base = op[:-1]
        size = "byte ptr " if op[-1] == "b" else "word ptr "
    if base in NOOP and not rest:
        return "        " + base
    if base not in TWO | ONE | REL:
        return None
    ops = split_operands(rest)
    masm = []
    for o in ops:
        c = att_operand(o, base)
        if c is None:
            return None
        masm.append(c)
    if base in TWO and len(masm) == 2:
        a, b = masm  # AT&T src,dst -> MASM dst,src
        if base == "in":       # in $port,%reg -> in reg, port
            a, b = b, a
        elif base == "out":    # out %al,$port -> out port, al
            a, b = b, a
        else:
            a, b = b, a
        if size:
            if a.startswith(("[", "byte", "word")) or ":[" in a:
                a = size + a
            elif b.startswith("[") or ":[" in b:
                b = size + b
        return f"        {base} {a}, {b}"
    if len(masm) == 1:
        a = masm[0]
        if size and (a.startswith("[") or ":[" in a):
            a = size + a
        return f"        {base} {a}" + comment
    return None


def convert_file(seg, src_path):
    row = next(l for l in open("disasm/function-map.tsv").read().splitlines()[1:]
               if l.split("\t")[0] == seg)
    fs = int(row.split("\t")[0], 16) + BIAS
    fe = int(row.split("\t")[1], 16) + BIAS
    body = open(src_path).read()
    # MASM dialect: '.'-prefixed local labels are not accepted by jwasm here
    body = re.sub(r"(?m)^(\s*)\.L", r"\1LC_", body)
    body = re.sub(r"(?m)(\s)(\.L)([\w$]+)", r"\1LC_\3", body)
    defined = {m.group(1) for ln in body.splitlines()
               if (m := re.fullmatch(r"([\w$.]+):", ln))}
    refs = set(re.findall(r"\bL_[0-9a-f]{6}\b", body))
    ext = {r for r in refs if r not in defined}
    out = ["        .MODEL TINY", "        .CODE"]
    below = sorted((int(e[2:], 16), e) for e in ext if int(e[2:], 16) < fs)
    above = sorted((int(e[2:], 16), e) for e in ext if int(e[2:], 16) > fe)
    for a, e in below:
        out += [f"        ORG 0{a:x}h", f"{e}:"]
    out.append(f"        ORG 0{fs:x}h")
    failed = []
    for ln in body.splitlines():
        if ln.startswith("#") or not ln.strip():
            out.append(";" + ln[1:] if ln.startswith("#") else "")
            continue
        m = re.fullmatch(r"([\w$.]+):", ln)
        if m:
            out.append(f"{m.group(1)}:")
            continue
        c = convert_line(ln)
        if c is None:
            failed.append(ln)
            out.append(";CONVERT-FAIL " + ln.strip())
        else:
            out.append(c)
    for a, e in above:
        out += [f"        ORG 0{a:x}h", f"{e}:"]
    out.append("        END")
    return "\n".join(out), failed


def jwasm_match(seg, masm_text, workdir):
    src = os.path.join(workdir, f"{seg}.asm")
    open(src, "w").write(masm_text)
    jw = os.path.abspath(os.environ.get("JWASM", "tools/jwasm/jwasm"))
    r = subprocess.run([jw, "-bin", f"-Fo{seg}.bin", src],
                       capture_output=True, text=True, cwd=workdir)
    binp = os.path.join(workdir, f"{seg}.bin")
    if r.returncode != 0 or not os.path.exists(binp):
        return False, (r.stdout + r.stderr)[:300]
    row = next(l for l in open("disasm/function-map.tsv").read().splitlines()[1:]
               if l.split("\t")[0] == seg)
    fs = int(row.split("\t")[0], 16) + BIAS
    fe = int(row.split("\t")[1], 16) + BIAS
    orig = open("original/ultimaii.exe", "rb").read()
    out = open(binp, "rb").read()
    # jwasm -bin starts output at the FIRST EMITTED byte (leading ORG padding
    # is stripped); our first emitted byte is at file offset fs.
    mine = out[:fe - fs + 1]
    if mine == orig[fs:fe + 1]:
        return True, ""
    return False, f"byte diff: {sum(1 for a, b in zip(orig[fs:fe+1], mine) if a != b)}B (len {len(mine)}/{fe-fs+1})"


def main():
    args = sys.argv[1:]
    segs = [a.upper() for a in args if not a.startswith("--")]
    if "--sample" in args:
        n = int(args[args.index("--sample") + 1])
        allf = sorted(os.path.basename(p).split("_")[0]
                      for p in glob.glob("asm/*.asm"))
        step = max(1, len(allf) // n)
        segs = allf[::step][:n]
    npass = nfail = nconv = 0
    for seg in segs:
        src = glob.glob(f"asm/{seg}_*.asm")
        if not src:
            print(f"SKIP {seg} (no cleaned file)")
            continue
        text, failed = convert_file(seg, src[0])
        if failed:
            nconv += 1
            print(f"CONVERT-FAIL {seg}: {len(failed)} lines, e.g. {failed[0].strip()[:60]}")
            continue
        with tempfile.TemporaryDirectory() as d:
            ok, why = jwasm_match(seg, text, d)
        if ok:
            npass += 1
        else:
            nfail += 1
            print(f"JWASM-DIFF {seg}: {why}")
    print(f"# dialect: {npass} dual-match, {nfail} jwasm-diff, "
          f"{nconv} convert-fail, {len(segs)} requested")
    sys.exit(0 if nfail == 0 and nconv == 0 else 1)


if __name__ == "__main__":
    main()
