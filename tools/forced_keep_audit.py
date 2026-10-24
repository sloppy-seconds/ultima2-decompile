#!/usr/bin/env python3
"""forced_keep_audit.py — how many asm/ files hide a mis-decode behind a forced-keep?

THE SIGNATURE
-------------
A `.byte` line marked `forced-kept: gas re-encodes '<X>' differently` means the decode
tool reached an address, decided instruction <X> lived there, and kept raw bytes because
gas would not re-encode <X> the way the original bytes read.

If the tool's instruction-length estimate was WRONG, the `.byte` list holds only the
first few bytes of a longer instruction, and the remaining bytes were then decoded as
separate instructions. That is what happened at asm/353A / asm/353D: the forced-keep was
one byte, `0x8a`, the real instruction was four, `8a 1e 49 00` = `mov 0x49,%bl`, and the
next file opened with `push %ds` (the ModRM byte) and `dec %cx` (the displacement). A
four-byte instruction became a forced-keep plus three invented instructions, and it hid
the DS:49 read that G14 needed.

THE TEST
--------
Per file with forced-keeps: decode the original bytes linearly from the file's own start
(the sanctioned method: "decode from each function's own start", disasm/phase2-summary.md)
with objdump, then walk the asm body advancing a cursor:
  * a `.byte` line advances by the number of bytes it lists
  * a `db "..."` line advances by the literal's byte length
  * any other instruction line must land on an offset objdump also started an instruction
    at, and advances by objdump's length for it
A cursor that lands strictly INSIDE an objdump instruction is a mis-decode: the asm drew
an instruction boundary where the real instruction is still running. A `.byte` whose count
is smaller than the instruction objdump starts there is the forced-keep variant of the same
thing, and is reported separately because it names the culprit line.

Read-only. Writes nothing but the optional --tsv output. Never touches asm/.

KNOWN LIMITATION — read this before quoting a number
---------------------------------------------------
`begins-mid-insn` is **provisional and inflated**. It anchors a linear objdump pass on the
previous fragment's start, and where that fragment contains inline string data (`db "..."`)
objdump decodes the string bytes as code and invents long instructions that swallow the next
real boundary. Verified false positive: asm/0155 is flagged, but the bytes are
`e8 91 4e` call, `"ORIGIN\0"` at 014E..0154, then `bf 0b 00` = `mov $0xb,%di` at 0155,
which is exactly what the asm says. The flag came from objdump reading the NUL as the start
of a 4-byte `add %bh,...`.

`partial-forced-keep` is the defensible signal: it compares a forced-keep's own byte count
against the instruction objdump starts AT that address, and it was hand-verified on two
independent cases (asm/353A, and asm/025D where `movb $0x3,0x2f` was kept as one byte and
the following fragment invented `push %es` / `das` / `add %al,(%bp,%di)`). Both controls are
enforced by --selftest.

A trustworthy invented-mnemonic count needs the decode to consume `db` lines from the asm
instead of trusting a linear pass over them. That is a real fix, not a flag.

Usage:
    tools/forced_keep_audit.py [--tsv] [--verbose] [--selftest] [--limit N]
"""
from __future__ import annotations

import argparse
import glob
import os
import re
import subprocess
import sys
import tempfile

EXE = "original/ultimaii.exe"
BIAS = 0x200
FUNC_RE = re.compile(r"^#\s*func\s+([0-9A-Fa-f]{4})\.\.([0-9A-Fa-f]{4})", re.M)
LABEL_RE = re.compile(r"^L_([0-9a-fA-F]{6}):")
BYTE_RE = re.compile(r"^\s*\.byte\s+([0-9A-Fa-fx,\s]+?)\s*(?:#.*)?$")
DB_RE = re.compile(r'^\s*db\s+"(.*?)"(.*)$')
FORCED_RE = re.compile(r"forced-kept:.*?re-encodes\s+'(.*?)'\s+differently")
HEXB_RE = re.compile(r"0x([0-9a-fA-F]{2})")


def die(msg: str):
    print(f"forced_keep_audit: ERROR: {msg}")
    sys.exit(2)


def objdump_lengths(data: bytes, start: int, end: int) -> dict[int, int]:
    """Linear decode of file bytes [start,end). Returns {file_offset: insn_len}.

    NOTE: callers must pass a window WIDER than the region of interest. An instruction
    that starts inside a short fragment and runs past its end cannot be measured inside
    the fragment alone -- objdump has no bytes left to decode. That is not an edge case,
    it is the entire defect this tool looks for: the first version decoded only the
    fragment's own span, silently skipped every forced-keep whose instruction overflowed
    it, and reported 0 findings across 290 files including the one known-true case.
    """
    if end <= start:
        return {}
    chunk = data[start:end]
    with tempfile.NamedTemporaryFile(suffix=".bin", delete=False) as f:
        f.write(chunk)
        path = f.name
    try:
        p = subprocess.run(
            ["objdump", "-D", "-b", "binary", "-mi8086", "-Mintel,data16,addr16",
             f"--adjust-vma={start}", path],
            capture_output=True, text=True)
    finally:
        os.unlink(path)
    out: dict[int, int] = {}
    pat = re.compile(r"^\s+([0-9a-f]+):\t((?:[0-9a-f]{2} )+)")
    for line in p.stdout.splitlines():
        m = pat.match(line)
        if m:
            out[int(m.group(1), 16)] = len(m.group(2).split())
    return out


def db_byte_len(line: str) -> int:
    """Byte length of a `db` line: the string literal plus any trailing numeric bytes."""
    m = DB_RE.match(line)
    if not m:
        return 0
    n = len(m.group(1).encode("latin-1"))
    rest = m.group(2)
    n += len(re.findall(r"0x[0-9a-fA-F]{2}", rest))
    return n


def begins_mid_insn(data: bytes, s: int, anchor: int | None) -> str | None:
    """Does the fragment at runtime `s` start INSIDE an instruction that began earlier?

    The whole defect in one check, and it needs no walk of the file, so it cannot
    desynchronise and cascade the way a line-by-line cursor does. Decode from the PREVIOUS
    fragment's start — a discovered entry point, so far more likely to be a true
    instruction boundary than an arbitrary window — find the instruction containing `s`,
    and if it started before `s` then this fragment's first mnemonic is invented: the real
    instruction was still running when the map drew the boundary.

    asm/353D is the case: anchored at 353A the window decodes `b7 00` then `8a 1e 49 00`
    at 353C, which runs to 353F, so 353D sits mid-instruction and its `push %ds` is really
    a ModRM byte. Anchoring at a fixed offset instead lands inside inline string data and
    the decode is nonsense -- which is how the first version of this check missed 353D
    while correctly catching 353A.
    """
    fs = s + BIAS
    if anchor is None:
        return None
    lo = anchor + BIAS
    if lo >= fs:
        return None
    ins = objdump_lengths(data, lo, min(len(data), fs + 8))
    if not ins:
        return None
    for off in sorted(ins):
        if off <= fs < off + ins[off]:
            if off < fs:
                return (f"first insn at {s:04X} lies inside a {ins[off]}-byte insn "
                        f"starting at {off - BIAS:04X}")
            return None
    return None


def audit_file(path: str, data: bytes, anchor: int | None = None) -> list[dict]:
    text = open(path).read()
    fm = FUNC_RE.search(text)
    if not fm:
        return []
    s, e = int(fm.group(1), 16), int(fm.group(2), 16)
    fs, fe = s + BIAS, e + BIAS
    # decode past the fragment end: the defect is an insn that overflows the boundary
    ins = objdump_lengths(data, fs, min(len(data), fe + 1 + 24))
    if not ins:
        return []

    body = [ln for ln in text.splitlines() if not ln.lstrip().startswith("#")]
    cur = fs
    findings: list[dict] = []
    mid = begins_mid_insn(data, s, anchor)
    if mid:
        findings.append({"file": os.path.basename(path), "addr": f"{s:04X}",
                         "kind": "begins-mid-insn", "detail": mid})
    for ln in body:
        if not ln.strip():
            continue
        if LABEL_RE.match(ln):
            lbl = int(LABEL_RE.match(ln).group(1), 16)
            # labels are file offsets; trust them only as re-anchors when aligned
            if lbl in ins or lbl >= cur:
                cur = lbl
            continue
        if ln.startswith(("sub_", "clock_", "key_", "video_", "dos_", "speaker_")) \
                and ln.rstrip().endswith(":"):
            continue
        bm = BYTE_RE.match(ln)
        if bm:
            nbytes = len(HEXB_RE.findall(bm.group(1)))
            forced = FORCED_RE.search(ln)
            if cur in ins:
                real = ins[cur]
                if forced and nbytes < real:
                    findings.append({
                        "file": os.path.basename(path), "addr": f"{cur - BIAS:04X}",
                        "kind": "partial-forced-keep",
                        "detail": f"{nbytes} B kept, real insn {real} B "
                                  f"(gas said `{forced.group(1).strip()}`)"})
            elif forced:
                findings.append({
                    "file": os.path.basename(path), "addr": f"{cur - BIAS:04X}",
                    "kind": "undecodable-forced-keep",
                    "detail": f"{nbytes} B kept and objdump cannot decode an insn "
                              f"here at all (gas said `{forced.group(1).strip()}`)"})
            cur += max(nbytes, 1)
            continue
        dm = DB_RE.match(ln)
        if dm:
            cur += max(db_byte_len(ln), 1)
            continue
        # a real instruction line: must sit on an objdump instruction start
        if cur in ins:
            cur += ins[cur]
        else:
            nxt = min((o for o in ins if o > cur), default=fe + 1)
            findings.append({
                "file": os.path.basename(path), "addr": f"{cur - BIAS:04X}",
                "kind": "boundary-inside-insn",
                "detail": f"asm starts an insn at {cur - BIAS:04X}, objdump's insn "
                          f"there began earlier and runs to {nxt - BIAS - 1:04X}"})
            cur = nxt
    return findings


def selftest(data: bytes) -> int:
    """The control that should have existed from the start.

    asm/353A is a KNOWN-TRUE case, proved by hand on 2026-10-28d: one byte (`0x8a`) was
    forced-kept and the real instruction is four (`8a 1e 49 00` = `mov 0x49,%bl`). A
    detector that misses it is worthless, and the first version of this tool missed it and
    printed a clean bill of health for 290 files.
    """
    hits = audit_file("asm/353A_sub_353a.asm", data)
    ok = any(h["kind"] in ("partial-forced-keep", "undecodable-forced-keep")
             and h["addr"] == "353C" for h in hits)
    print("CONTROL  asm/353A @353C must be flagged (partial forced-keep) -> "
          f"{'OK' if ok else 'MISSED'}")
    hits2 = audit_file("asm/353D_sub_353d.asm", data, anchor=0x353A)
    ok2 = any(h["kind"] == "begins-mid-insn" for h in hits2)
    print("CONTROL  asm/353D must be flagged (first insn is invented)      -> "
          f"{'OK' if ok2 else 'MISSED'}   ({hits2})")
    if not (ok and ok2):
        print("SELFTEST: FAIL — the detector does not see the cases proven by hand. "
              "Do not trust any count from this tool.")
        return 1
    print("SELFTEST: PASS")
    return 0


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--tsv", action="store_true")
    ap.add_argument("--verbose", action="store_true")
    ap.add_argument("--selftest", action="store_true")
    ap.add_argument("--limit", type=int, default=0)
    a = ap.parse_args()

    if not os.path.exists(EXE):
        die(f"{EXE} not present; this audit needs the original executable")
    data = open(EXE, "rb").read()

    if a.selftest:
        return selftest(data)

    # Scan EVERY file, not only the ones containing forced-keeps. The first version
    # filtered to forced-keep files and so never looked at asm/353D — which is the file
    # holding the invented `push %ds` / `dec %cx`, one fragment AFTER the forced-keep that
    # caused them. The forced-keep is the cause; the bad mnemonics are usually next door.
    files = sorted(glob.glob("asm/*.asm"))
    if a.limit:
        files = files[: a.limit]

    all_f: list[dict] = []
    # previous fragment start per file, so each check is anchored on a discovered entry
    prev: dict[str, int | None] = {}
    last: int | None = None
    for p in files:
        m = re.match(r"asm/([0-9A-Fa-f]{4})_", p)
        prev[p] = last
        if m:
            last = int(m.group(1), 16)
    for p in files:
        all_f.extend(audit_file(p, data, prev.get(p)))

    partial = [f for f in all_f if f["kind"] == "partial-forced-keep"]
    inside = [f for f in all_f if f["kind"] == "begins-mid-insn"]
    cascade = [f for f in all_f if f["kind"] == "boundary-inside-insn"]
    files_hit = {f["file"] for f in all_f}

    if a.tsv:
        print("file\taddr\tkind\tdetail")
        for f in all_f:
            print(f"{f['file']}\t{f['addr']}\t{f['kind']}\t{f['detail']}")
        return 0

    print(f"scanned {len(files)} asm/ files")
    print(f"  BEGINS-MID-INSN   (PROVISIONAL, inflated by inline strings): {len(inside)}")
    print(f"  partial-forced-keep (DEFENSIBLE signal):                     {len(partial)}")
    print(f"  walk divergences    (unreliable: desync cascades):          {len(cascade)}")
    reliable = {f["file"] for f in inside} | {f["file"] for f in partial}
    print(f"  FILES hit by the two reliable signals:                      {len(reliable)}")
    if inside:
        print("\nfragments whose first instruction is not the real instruction:")
        for f in inside[: (40 if a.verbose else 15)]:
            print(f"  {f['file']}  {f['detail']}")
        if len(inside) > (40 if a.verbose else 15):
            print(f"  ... {len(inside) - (40 if a.verbose else 15)} more")
    if partial:
        print("\npartial forced-keeps (the 353A signature):")
        for f in partial[: (40 if a.verbose else 15)]:
            print(f"  {f['file']}  {f['addr']}  {f['detail']}")
        if len(partial) > (40 if a.verbose else 15):
            print(f"  ... {len(partial) - (40 if a.verbose else 15)} more")
    return 0


if __name__ == "__main__":
    sys.exit(main())
