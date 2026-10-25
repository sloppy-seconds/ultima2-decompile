#!/usr/bin/env python3
"""recut_bytes.py — turn a `db`-rendered code span back into mnemonics, gas-verified.

WHY THIS EXISTS
---------------
The clean wave gave up on several spans and rendered every instruction as a raw-byte `db`
line marked `split: branch target inside data`. asm/72A0 is 4.3 KB of that and genuinely is
mixed, but asm/6144 was 333 bytes of plain code — a `call`, a `mov`, an moffs store — shown
as 160 byte lines. The ranked list is in `disasm/defects.md`.

THE CONTRACT
------------
Nothing here is asserted from a disassembly alone. For each line: objdump decodes the bytes
to an AT&T mnemonic, then **gas is asked to assemble that mnemonic at the line's real
address**, with any branch target's label defined at the target's address, and the result is
compared byte-for-byte. Equal means the mnemonic is emitted. Different means the line stays a
`.byte` forced-keep naming what gas was asked for — which is the tree's existing honest form
for the register-to-register dialect cases (`mov %bx,%di` is `8b fb` in the binary and gas
emits `89 df`).

So the tool cannot introduce a byte change: `tools/check_func.py` on the span is the gate, and
`assemble_clean.sh` is the proof. The two polarities are pinned by `--selftest`: a forward
`call` must come back as a mnemonic (it did not, in the first version, because `.org` cannot
seek backwards and the mnemonic landed at the target instead), and `mov %bx,%di` must come
back as a forced-keep.

Read-only over the repo: prints a candidate body to stdout, writes nothing. Apply it by hand
with the edit tool, add a `# body corrected:` marker, then run check_func.

Usage:
    tools/recut_bytes.py asm/<FILE>.asm          # candidate body to stdout
    tools/recut_bytes.py --selftest
"""
import os
import re
import subprocess
import sys
import tempfile

BIAS = 0x200
EXE = "original/ultimaii.exe"
LABEL_RE = re.compile(r"^L_([0-9a-fA-F]{6}):")
DB_RE = re.compile(r'^\s*db\s+(.*?)\s*(?:#.*)?$')
BYTE_RE = re.compile(r"^\s*\.byte\s+([0-9A-Fa-fx,\s]+?)\s*(?:#.*)?$")
REL = re.compile(r"\b(call|jmp|je|jne|ja|jae|jb|jbe|jg|jge|jl|jle|jo|jno|js|jns|loopnz|loopne|loopz|loop|jz|jnz)\b")


def objdump_att(data, addr, raw):
    # objdump treats a short buffer as trailing padding and prints `...` instead of decoding
    # it: two bytes of 0x00 came back undecodable, which would have left real instructions as
    # raw bytes. Padding the buffer with NOPs makes it decode the first instruction normally;
    # only the first line is ever read back.
    with tempfile.TemporaryDirectory(dir="/var/tmp") as d:
        p = os.path.join(d, "b.bin")
        open(p, "wb").write(raw + b"\x90" * 8)
        r = subprocess.run(["objdump", "-D", "-b", "binary", "-mi8086", "-Matt,data16,addr16",
                            f"--adjust-vma={addr + BIAS}", p], capture_output=True, text=True)
    for line in r.stdout.splitlines():
        m = re.match(r"\s+[0-9a-f]+:\s+((?:[0-9a-f]{2}\s+)+)\s*(\S.*)$", line)
        if m:
            return m.group(2).strip()
    return None


def gas_bytes(mnem, addr, refs):
    # The instruction must be assembled AT its own address, and every branch target must have
    # its label defined at the target's address — and `.org` cannot seek backwards, so the
    # stops have to be emitted in address order with the mnemonic slotted between them. The
    # first version emitted all the target labels after the instruction's `.org`, which put the
    # mnemonic at the target instead, and made forward branches (the common case) look like a
    # gas dialect problem.
    here = addr + BIAS
    body = [".code16", ".text"]
    for t in sorted(r for r in refs if r < here):
        body += [f".org 0x{t:06X}", f"L_{t:06x}:"]
    body += [f".org 0x{here:06X}", mnem]
    for t in sorted(r for r in refs if r > here):
        body += [f".org 0x{t:06X}", f"L_{t:06x}:"]
    with tempfile.TemporaryDirectory(dir="/var/tmp") as d:
        src = os.path.join(d, "t.s")
        open(src, "w").write("\n".join(body) + "\n")
        if subprocess.run(["as", "-o", os.path.join(d, "o"), src],
                          capture_output=True, text=True).returncode:
            return None
        subprocess.run(["objcopy", "-O", "binary", "--only-section=.text",
                        os.path.join(d, "o"), os.path.join(d, "b")], capture_output=True)
        if not os.path.exists(os.path.join(d, "b")):
            return None
        raw = open(os.path.join(d, "b"), "rb").read()
    off = addr + BIAS
    return raw[off:] if len(raw) > off else b""


def main(path):
    data = open(EXE, "rb").read()
    text = open(path).read()
    out = []
    cur = None
    for ln in text.splitlines():
        lm = LABEL_RE.match(ln)
        if lm:
            cur = int(lm.group(1), 16)
            out.append(ln)
            continue
        if not ln.strip() or ln.lstrip().startswith("#"):
            out.append(ln)
            continue
        m = DB_RE.match(ln) or BYTE_RE.match(ln)
        if not m or cur is None:
            out.append(ln)
            continue
        raw = bytes(int(x, 16) for x in re.findall(r"0x([0-9a-fA-F]{2})", m.group(1)))
        if not raw:
            out.append(ln)
            continue
        mnem = objdump_att(data, cur - BIAS, raw)
        if mnem is None:
            out.append(f"        .byte {', '.join('0x%02x' % x for x in raw)}  # undecodable")
            continue
        refs = set()
        # rewrite absolute branch targets back to L_ labels
        rm = REL.match(mnem)
        if rm:
            tgt = re.search(r"0x([0-9a-f]+)\s*(?:<.*>)?\s*$", mnem)
            if tgt:
                t = int(tgt.group(1), 16)
                if t >= 0x1000:          # in-image file offset
                    refs.add(t)
                    mnem = f"{rm.group(1)} L_{t:06x}"
        got = gas_bytes(mnem, cur - BIAS, refs)
        if got is not None and got[:len(raw)] == raw:
            out.append(f"        {mnem}")
        else:
            out.append("        .byte " + ", ".join("0x%02x" % x for x in raw)
                       + f"  # forced-kept: gas re-encodes '{mnem}' differently")
    print("\n".join(out))


def selftest() -> int:
    """Both polarities, because a verifier that always says `yes` and one that always says
    `no` look identical until you test one of each.

    A forward `call` MUST come back as a mnemonic. The first version of this tool emitted the
    target label before the instruction's own `.org`, gas could not seek backwards, and the
    mnemonic was assembled at the target address instead — so every forward branch looked like
    a gas dialect problem and would have been left as a forced-keep. That is a silent
    under-claim: plausible, wrong, and it makes the tree look more uncertain than it is.

    `mov %bx,%di` MUST come back as a forced-keep. The binary has `8b fb`, gas emits `89 df`;
    same instruction, different bytes. If this tool ever reports it as a mnemonic it has
    stopped comparing and is guessing.
    """
    bad = 0
    pad = objdump_att(b"\0" * 64, 0x4ACD, bytes([0x00, 0x00]))
    ok_pad = pad is not None and pad.startswith("add")
    print(f"CONTROL  a two-byte 0x00 buffer must decode, not print '...'          -> "
          f"{'OK' if ok_pad else 'BROKEN'}   ({pad})")
    fwd = gas_bytes("call L_006625", 0x634c - BIAS, {0x6625})
    ok_fwd = fwd is not None and fwd[:3] == bytes([0xE8, 0xD6, 0x02])
    print(f"CONTROL  forward call encodes to e8 d6 02 at its own address -> "
          f"{'OK' if ok_fwd else 'BROKEN'}   ({fwd[:3].hex(' ') if fwd else None})")
    reg = gas_bytes("mov    %bx,%di", 0x6355 - BIAS, set())
    ok_reg = reg is not None and reg[:2] != bytes([0x8B, 0xFB])
    print(f"CONTROL  gas must differ on `mov %bx,%di` (stays a forced-keep) -> "
          f"{'OK' if ok_reg else 'BROKEN'}   ({reg[:2].hex(' ') if reg else None})")
    if not (ok_pad and ok_fwd and ok_reg):
        print("SELFTEST: FAIL — the gas comparison is not working; do not trust any output.")
        bad = 1
    else:
        print("SELFTEST: PASS")
    return bad


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "--selftest":
        sys.exit(selftest())
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(2)
    main(sys.argv[1])
