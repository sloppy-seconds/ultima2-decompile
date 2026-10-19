#!/usr/bin/env python3
"""Phase 3: mechanical pre-clean of a Phase 2 slice (CP2 pilot, CP4 bulk).

Usage: tools/preclean.py <SEG>   -> prints cleaned skeleton to stdout

Transforms (all byte-preserving; check_func.py is the proof):
  * runs of `# string` .byte lines -> db "printable...",NUL items
    (non-printables stay numeric; '"' and '\\' escaped). Runs may be
    interleaved with per-byte label lines: a label NOT referenced anywhere
    in the corpus is dropped; a referenced one splits the run.
  * consecutive `# zeros` runs -> db 0,... (wrapped at 16/line)
  * other same-kind runs (table/gap-pad/tail-pad) -> merged db
  * `# forced: <plain insn>` restored to the instruction; rel-op targets
    become L_<6hex> file-offset labels (slice convention).
    `stop-trunc` forces are KEPT as .byte (operand straddles the range).
  * everything else passes through verbatim
"""
import glob
import re
import subprocess
import sys
import tempfile

PRINTABLE = set(range(0x20, 0x7F))
REL_OPS = {"call", "jmp", "je", "jne", "ja", "jae", "jb", "jbe", "jg", "jge",
           "jl", "jle", "jo", "jno", "js", "jns", "jc", "jnc", "jp", "jnp",
           "jcxz", "loop", "loope", "loopne"}
BYTE_RE = re.compile(r"^\s+\.byte\s+(\S+)\s+#\s*(string|zeros|table|gap-pad|tail-pad)\s*$")
FORCED_RE = re.compile(r"^\s+\.byte\s+(\S+)\s+#\s*forced:\s*(.*)$")
LABEL_RE = re.compile(r"^(\w[\w$.]*):$")


def corpus_referenced():
    """L_ labels used as an operand anywhere in disasm/functions/*.asm,
    including targets hidden inside '# forced: <rel-op> 0xNNNN' comments."""
    refs = set()
    for f in glob.glob("disasm/functions/*.asm"):
        for line in open(f).read().splitlines():
            if LABEL_RE.match(line):
                continue
            refs.update(re.findall(r"\bL_[0-9a-f]{6}\b", line))
            fm = FORCED_RE.match(line)
            if fm:
                mt = re.fullmatch(r"(\w+)\s+(0x[0-9a-f]+)", fm.group(2).strip())
                if mt and mt.group(1).lower() in REL_OPS:
                    refs.add(f"L_{int(mt.group(2), 16):06x}")
    return refs


def parse_bytes(text):
    return [int(x, 16) for x in re.findall(r"0x([0-9a-fA-F]{2})", text)]


def str_item(bs):
    out = []
    for b in bs:
        c = chr(b)
        out.append('\\"' if c == '"' else "\\\\" if c == "\\" else c)
    return '"' + "".join(out) + '"'


def emit_run(kind, bs):
    if kind == "string":
        items, run = [], []
        for b in bs + [None]:
            if b is not None and b in PRINTABLE:
                run.append(b)
                continue
            if run:
                items.append(str_item(run))
                run = []
            if b is not None:
                items.append(f"0x{b:02x}")
        return [f"        db {','.join(items)}        # string"]
    if kind == "zeros":
        n, lines = len(bs), []
        while n > 0:
            k = min(n, 16)
            lines.append("        db " + ",".join(["0"] * k) + "        # zeros")
            n -= k
        return lines
    items = ",".join(f"0x{b:02x}" for b in bs)
    return [f"        db {items}        # {kind}"]


def verify_encodings(cands):
    """Batch-assemble plain (label-free) candidate instructions; return the set
    whose gas encoding equals the original bytes EXACTLY (length included).
    Lengths are measured with end-symbols, not zero-scan heuristics."""
    if not cands:
        return set()
    lines = ["        .code16", "        .text"]
    for idx, (text, _) in enumerate(cands):
        lines.append(f"        .org {idx * 32}")
        lines.append(f"__v{idx}:")
        lines.append("        " + text)
        lines.append(f"__v{idx}_end:")
    with tempfile.TemporaryDirectory() as d:
        s = f"{d}/v.s"
        open(s, "w").write("\n".join(lines) + "\n")
        r = subprocess.run(["as", "--32", "-o", f"{d}/v.o", s],
                           capture_output=True, text=True)
        if r.returncode != 0:
            return set()
        subprocess.run(["objcopy", "-j", ".text", "-O", "binary",
                        f"{d}/v.o", f"{d}/v.bin"], check=True)
        blob = open(f"{d}/v.bin", "rb").read()
        nm = subprocess.run(["nm", f"{d}/v.o"], capture_output=True,
                            text=True).stdout
    pos = {}
    for m in re.finditer(r"([0-9a-f]{8}) [tTbBdD] (__v\d+(?:_end)?)", nm):
        pos[m.group(2)] = int(m.group(1), 16)
    ok = set()
    for idx, (text, orig_bs) in enumerate(cands):
        a, b = pos.get(f"__v{idx}"), pos.get(f"__v{idx}_end")
        if a is None or b is None:
            continue
        if list(blob[a:b]) == orig_bs:
            ok.add(text)
    return ok


def try_restore_forced(ln, verified):
    m = FORCED_RE.match(ln)
    if not m:
        return None
    text = m.group(2).strip()
    if "stop-trunc" in text:
        return ln.replace("# forced:", "# forced-kept:")
    mt = re.fullmatch(r"(\w+)\s+(0x[0-9a-f]+)", text)
    if mt and mt.group(1).lower() in REL_OPS:
        bs = parse_bytes(m.group(1))
        op = mt.group(1).lower()
        fits = ((len(bs) == 3) if op in ("call", "jmp") else
                (len(bs) == 4) if bs and bs[0] == 0x0F else (len(bs) == 2))
        if fits:
            return f"        {mt.group(1)} L_{int(mt.group(2), 16):06x}"
        return ln.replace("# forced:", "# forced-kept:")
    if text in verified:
        return "        " + text
    return ln.replace("# forced:", "# forced-kept:")


def missing_rev(missing, addr):
    return next(n for n, a in missing.items() if a == addr)


def main():
    seg = sys.argv[1].upper()
    lines = open(f"disasm/functions/{seg}.asm").read().splitlines()
    referenced = corpus_referenced()
    defined_here = {m.group(1) for ln in lines
                    if (m := LABEL_RE.match(ln))}
    # referenced labels with no definition in this slice: they point into
    # mis-decoded runs; split data runs at their true addresses
    missing = {n: int(n[2:], 16) for n in referenced
               if n not in defined_here and n.startswith("L_")}
    # pass 1: batch-verify plain forced candidates against original bytes
    plain_cands = []
    for ln in lines:
        m = FORCED_RE.match(ln)
        if not m or "stop-trunc" in m.group(2):
            continue
        mt = re.fullmatch(r"(\w+)\s+(0x[0-9a-f]+)", m.group(2).strip())
        if mt and mt.group(1).lower() in REL_OPS:
            continue
        if re.fullmatch(r"\w+(\s+\S.*)?", m.group(2).strip()):
            plain_cands.append((m.group(2).strip(), parse_bytes(m.group(1))))
    verified = verify_encodings(plain_cands)

    out, i = [], 0
    while i < len(lines):
        m = BYTE_RE.match(lines[i])
        if not m:
            out.append(try_restore_forced(lines[i], verified) or lines[i])
            i += 1
            continue
        kind = m.group(2)
        # run start address = preceding L_ label line, if any
        prev = lines[i - 1] if i else ""
        pm = re.match(r"^L_([0-9a-f]{6}):$", prev)
        run_addr = int(pm.group(1), 16) if pm else None
        # segments: (label_or_None, bytes); a referenced label inside a run
        # splits it, an unreferenced one is dropped
        segs = [(None, parse_bytes(lines[i]))]
        j = i + 1
        while j < len(lines):
            lm = LABEL_RE.match(lines[j])
            if lm:
                nxt = lines[j + 1] if j + 1 < len(lines) else ""
                nm = BYTE_RE.match(nxt)
                if nm and nm.group(2) == kind:
                    if lm.group(1) in referenced:
                        segs.append((lm.group(1), []))
                    j += 1
                    continue
                break
            bm = BYTE_RE.match(lines[j])
            if bm and bm.group(2) == kind:
                segs[-1] = (segs[-1][0], segs[-1][1] + parse_bytes(lines[j]))
                j += 1
                continue
            break
        # split segments at missing-label addresses inside the run
        if run_addr is not None and missing:
            split = []
            addr = run_addr
            for lab, bs in segs:
                if lab:
                    addr = int(lab[2:], 16)
                cuts = sorted(a for a in set(missing.values())
                              if addr < a < addr + len(bs))
                if not cuts:
                    split.append((lab, bs))
                    addr += len(bs)
                    continue
                last, first = 0, True
                for a in cuts:
                    end = a - addr
                    if end > last:
                        split.append((lab if first else None, bs[last:end]))
                        first = False
                    split.append((missing_rev(missing, a), []))
                    last = end
                if last < len(bs):
                    split.append((lab if first else None, bs[last:]))
                addr += len(bs)
            segs = split
        for lab, bs in segs:
            if lab:
                out.append(f"{lab}:")
            out += emit_run(kind, bs)
        i = j
    while out and re.match(r"^# func ", out[-1]):
        out.pop()
    print("\n".join(out))


if __name__ == "__main__":
    main()
