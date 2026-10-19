#!/usr/bin/env python3
"""Phase 3: string-aware recursive decode of a function range.

Usage: tools/decode_str.py <SEG>

objdump's linear decode desynchronises when a `call str_out` is followed by
inline string bytes (the mis-decode class behind Phase 2's forced .byte lines).
This decoder runs objdump over the range, and whenever a call to a known
string-display entry (file 0x51df) is decoded, it emits the following raw
bytes up to and including the NUL as `db "..."` and RESTARTS the decode after
the terminator. Output is a skeleton for hand-polish; check_func.py is proof.
"""
import re
import subprocess
import sys

sys.path.insert(0, "tools")
from preclean import verify_encodings, REL_OPS  # noqa: E402

EXE = "original/ultimaii.exe"
BIAS = 0x200
STROUT = 0x51DF


def objdump_range(data, start, stop):
    r = subprocess.run(
        ["objdump", "-d", "-b", "binary", "-m", "i8086", "-j", ".data",
         f"--start-address={start}", f"--stop-address={stop}", EXE],
        capture_output=True, text=True)
    rows = []
    for line in r.stdout.splitlines():
        m = re.match(r"\s+([0-9a-f]+):\t((?:[0-9a-f]{2} )+) *\t(.*)", line)
        if m:
            raw = bytes.fromhex(m.group(2).replace(" ", ""))
            text = m.group(3).split("#")[0].rstrip()
            rows.append((int(m.group(1), 16), [f"{b:02x}" for b in raw], text))
    return rows


def rel_target(text):
    m = re.fullmatch(r"(\w+)\s+(0x[0-9a-f]+)", text)
    if m:
        return m.group(1).lower(), int(m.group(2), 16)
    return None, None


def main():
    seg = sys.argv[1].upper()
    row = next(l for l in open("disasm/function-map.tsv").read().splitlines()[1:]
               if l.split("\t")[0] == seg)
    fs = int(row.split("\t")[0], 16) + BIAS
    fe = int(row.split("\t")[1], 16) + BIAS
    data = open(EXE, "rb").read()
    # pre-verify every plain instruction decode in the range against the
    # original bytes (gas may pick disp8 or a different reg-op form)
    allrows = objdump_range(data, fs, fe + 1)
    verified = verify_encodings([(t, list(data[a:a + len(h)]))
                                 for a, h, t in allrows
                                 if rel_target(t)[0] is None])
    out = []
    cursor = fs
    while cursor <= fe:
        rows = objdump_range(data, cursor, fe + 1)
        if not rows:  # objdump elides repeated-fill runs (zeros)
            rest = data[cursor:fe + 1]
            if rest:
                out.append("        db "
                           + ",".join(f"0x{b:02x}" for b in rest)
                           + "        # tail-pad")
            break
        i = 0
        while i < len(rows):
            addr, hexbs, text = rows[i]
            if addr > fe:
                break
            op, tgt = rel_target(text)
            if op == "call" and tgt == STROUT and len(hexbs) == 3:
                try:
                    end = data.index(0x00, addr + len(hexbs))
                except ValueError:
                    end = len(data)
                if end <= fe:  # string fully inside range: consume it
                    s = addr + len(hexbs)
                    bs = data[s:end + 1]
                    out.append(f"L_{addr:06x}:")
                    out.append(f"        call L_{STROUT:06x}")
                    items, run = [], []
                    for b in list(bs) + [None]:
                        if b is not None and 0x20 <= b < 0x7F and b not in (0x22, 0x5C):
                            run.append(chr(b))
                            continue
                        if run:
                            items.append('"' + "".join(run) + '"')
                            run = []
                        if b is not None:
                            items.append(f"0x{b:02x}")
                    out.append("        db " + ",".join(items) + "        # string")
                    cursor = end + 1
                    break  # restart objdump from cursor
                # else: straddling call — fall through to plain emit
            out.append(f"L_{addr:06x}:")
            if op in REL_OPS and tgt is not None:
                want = (2 if (op == "jmp" and hexbs[0] == "eb") else
                        3 if op in ("call", "jmp") else 2)
                if len(hexbs) != want:  # stop-trunc: operand outside range
                    out.append("        .byte "
                               + ",".join(f"0x{h}" for h in hexbs)
                               + f"  # forced-kept: stop-trunc {text}")
                else:
                    out.append(f"        {text.split()[0]} L_{tgt:06x}")
            elif rel_target(text)[0] is None and text not in verified:
                out.append("        .byte "
                           + ",".join(f"0x{h}" for h in hexbs)
                           + f"  # forced-kept: gas re-encodes '{text}' differently")
            else:
                out.append("        " + text)
            i += 1
            cursor = addr + len(hexbs)
        if cursor > fe:
            break
    print("\n".join(out))


if __name__ == "__main__":
    main()
