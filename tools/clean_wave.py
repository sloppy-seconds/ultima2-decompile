#!/usr/bin/env python3
"""Phase 3 CP4/CP5: batch-clean functions into asm/ with headers.

Usage: tools/clean_wave.py <SEG> [<SEG> ...]     (or --file LIST with one SEG/line)

Per function:
  1. decode_str.py skeleton (str_out-aware re-decode); fall back to
     preclean.py; if neither passes check_func, report DEFER (slice stays).
  2. Add style-guide header: name, range, evidence, confidence, and
     ACCURATE derived facts only (CP3 owner directive): inline strings found,
     call targets (annotated with known names), int/port seam labels.
  3. Write asm/<SEG>_<name>.asm, re-run check_func on the final file.

Exit 0 iff every requested function ended PASS. Prints one line per function.
"""
import argparse
import re
import subprocess
import sys

KNOWN = {0x51DF: "str_out"}
INT_SEAM = {0x10: "video_int10", 0x16: "key_int16", 0x1A: "clock_int1a",
            0x21: "dos_int21"}
PORT_SEAM = {0x61, 0x42, 0x43}


def run(cmd, **kw):
    return subprocess.run(cmd, capture_output=True, text=True, **kw)


def seams_and_facts(body):
    """Annotate int/port sites with seam labels; collect facts for header."""
    lines = body.splitlines()
    out, seen, facts = [], {}, {"strings": [], "calls": set(), "ints": set()}
    for ln in lines:
        m = re.match(r"^(\s+)int\s+\$0x([0-9a-f]+)(.*)$", ln)
        if m:
            num = int(m.group(2), 16)
            base = INT_SEAM.get(num)
            if base:
                seen[base] = seen.get(base, 0) + 1
                name = base if seen[base] == 1 else f"{base}_{seen[base]}"
                out.append(f"{name}:")
                out.append(f"{m.group(1)}int $0x{num:x}    # {name} seam"
                           + (m.group(3) or ""))
                facts["ints"].add(base)
                continue
        m = re.match(r"^(\s+)out\s+\$0x([0-9a-f]+),.*$", ln)
        if m and int(m.group(2), 16) in PORT_SEAM:
            out.append("speaker_tone:")
            out.append(ln + "    # speaker_tone seam (port " + m.group(2) + ")")
            facts["ints"].add("speaker_tone")
            continue
        m = re.search(r'^\s+db\s+"(.*?)".*# string', ln)
        if m and len(m.group(1)) > 1:
            facts["strings"].append(m.group(1))
        for cm in re.finditer(r"\b(?:call|jmp)\s+L_([0-9a-f]{6})", ln):
            facts["calls"].add(int(cm.group(1), 16))
        out.append(ln)
    body = "\n".join(out)
    # annotate known-name calls
    for addr, name in KNOWN.items():
        if name == "str_out":
            continue  # decode_str already annotates str_out sites
        body = re.sub(rf"(call L_{addr:06x})(?!.*#)", rf"\1    # {name}", body)
    return body, facts


def header(name, seg, ev, conf, facts, extra_notes=()):
    h = [f"# {name} — mechanical clean (bulk wave); behavior not yet reviewed",
         f"# func {seg}..{END[seg]}  len {LEN[seg]} B  evidence: {ev}"]
    if facts["strings"]:
        shown = facts["strings"][:4]
        h.append("# strings: " + "; ".join(f'"{s}"' for s in shown)
                 + (f" (+{len(facts['strings']) - 4} more)"
                    if len(facts["strings"]) > 4 else ""))
    if facts["calls"]:
        named = sorted(f"L_{a:06x}" + (f" ({KNOWN[a]})" if a in KNOWN else "")
                       for a in facts["calls"])
        h.append("# calls: " + ", ".join(named[:8])
                 + (f" (+{len(named) - 8} more)" if len(named) > 8 else ""))
    if facts["ints"]:
        h.append("# seams: " + ", ".join(sorted(facts["ints"])))
    h.append(f"# confidence: {conf} (bytes proven by check_func.py)")
    for n in extra_notes:
        h.append("# " + n)
    return "\n".join(h) + "\n"


END, LEN = {}, {}


def load_map():
    for l in open("disasm/function-map.tsv").read().splitlines()[1:]:
        s, e, ln, ev, hint = l.split("\t")
        END[s] = e
        LEN[s] = ln
        HINT[s.upper()] = hint
        EV[s.upper()] = ev


HINT, EV = {}, {}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("segs", nargs="*")
    ap.add_argument("--file")
    a = ap.parse_args()
    segs = [s.upper() for s in a.segs]
    if a.file:
        segs = [t.upper() for l in open(a.file) for t in l.split()]
    load_map()
    npass = ndef = 0
    for seg in segs:
        name = HINT.get(seg) or f"sub_{seg.lower()}"
        body = None
        for tool in ("decode_str.py", "preclean.py"):
            r = run([sys.executable, f"tools/{tool}", seg])
            if r.returncode != 0:
                continue
            tmp = f"tmp/wave/{seg}.skel"
            import os
            os.makedirs("tmp/wave", exist_ok=True)
            open(tmp, "w").write(r.stdout)
            c = run([sys.executable, "tools/check_func.py", seg,
                     "--file", tmp])
            if c.returncode == 0:
                body = r.stdout
                break
        if body is None:
            print(f"DEFER {seg} {name} (no generated decode passed)")
            ndef += 1
            continue
        body, facts = seams_and_facts(body)
        lines = body.splitlines()
        # first line is the entry L_ label; put name + anchor above it
        if lines and re.match(r"^L_[0-9a-f]{6}:$", lines[0]):
            addr = lines[0][:-1]
            entry = name if addr.lower() != name.lower() else ""
            head = header(name, seg, EV.get(seg, ""), "low", facts,
                          extra_notes=("bulk wave: L_<addr> labels kept as "
                                       "cross-reference anchors (CP3)",))
            final = head + (f"{name}:\n" if entry else "") + "\n".join(lines)
        else:
            final = header(name, seg, EV.get(seg, ""), "low", facts) + body
        path = f"asm/{seg}_{name}.asm"
        open(path, "w").write(final.rstrip() + "\n")
        c = run([sys.executable, "tools/check_func.py", seg])
        if c.returncode == 0:
            print(f"PASS {seg} {name}")
            npass += 1
        else:
            print(f"FAIL {seg} {name}: {c.stdout.strip().splitlines()[:2]}")
            # remove broken file so check_func falls back to the slice
            import os
            os.remove(path)
            ndef += 1
    print(f"# wave: {npass} pass, {ndef} defer/fail, {len(segs)} requested")
    sys.exit(0 if ndef == 0 else 1)


if __name__ == "__main__":
    main()
