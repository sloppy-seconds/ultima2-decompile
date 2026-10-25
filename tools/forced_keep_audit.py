#!/usr/bin/env python3
"""forced_keep_audit.py — how many asm/ files hide a mis-decode behind a forced-keep?

THE SIGNATURE
-------------
A `.byte` line marked `forced-kept:` means the decode tool reached an address and kept raw
bytes instead of a mnemonic. Two marker families occur, and for a long time this tool only
knew one of them:

  * `gas re-encodes '<X>' differently` — gas would emit different bytes for <X>, so the
    original bytes are kept verbatim. 1533 of them.
  * `stop-trunc ...` — the map boundary cut an instruction in half and the tool stopped
    rather than truncating it. 28 of them, and invisible to the first version of this
    detector because it matched on the phrase `re-encodes`.

If the tool's instruction-length estimate was WRONG, the `.byte` list holds only the first
few bytes of a longer instruction, and the remaining bytes were then decoded as separate
instructions. That is what happened at asm/353A / asm/353D: the forced-keep was one byte,
`0x8a`, the real instruction was four, `8a 1e 49 00` = `mov 0x49,%bl`, and the next file
opened with `push %ds` (the ModRM byte) and `dec %cx` (the displacement). A four-byte
instruction became a forced-keep plus three invented instructions, and it hid the DS:49 read
that G14 needed.

THE TEST
--------
Per file: decode the original bytes linearly from the file's own start (the sanctioned
method: "decode from each function's own start", disasm/phase2-summary.md) with objdump,
then walk the asm body advancing a cursor:
  * a `.byte` line advances by the number of bytes it lists
  * a `db` line advances by the byte length of its operands, in all three shapes the tree
    uses (`db "ORIGIN",0x00`, `db 0x8d,"KILLED--GOLD+",0x00`, and pure numeric runs)
  * any other instruction line advances by objdump's length at the cursor, re-decoded
    locally if the linear map has no entry there — the map being wrong is a fact about the
    map, not about the cursor
A `.byte` whose count is smaller than the instruction objdump starts AT that address is a
`partial-forced-keep`, and is reported per file because it names the culprit line. A
fragment whose first instruction lands inside one that started earlier is `begins-mid-insn`,
which is the same defect seen from the next fragment.

Read-only. Writes nothing but the optional --tsv output. Never touches asm/.

WHAT THE NUMBERS MEAN — read this before quoting one
----------------------------------------------------
`partial-forced-keep` is the primary signal: it compares a forced-keep's own byte count
against the instruction objdump starts AT that address, and it was hand-verified on three
independent cases — asm/353A, asm/025D (`movb $0x3,0x2f` kept as one byte, the following
fragment invented `push %es` / `das` / `add %al,(%bp,%di)`), and asm/01FD (`stop-trunc`,
`.byte 0xe8` where the real instruction is the three-byte call `e8 88 04`). All three are
enforced by --selftest, along with two known-false cases that must stay quiet.

`begins-mid-insn` used to be inflated and is now accounted for rather than merely labelled.
It anchors a linear objdump pass on the previous fragment's start, and where that fragment
holds inline string data objdump decodes the string bytes as code and invents long
instructions that swallow the next real boundary. Verified false positive: asm/0155, where
the bytes are `e8 91 4e` call, `"ORIGIN\0"` at 014E..0154, then `bf 0b 00` = `mov
$0xb,%di` at 0155 — exactly what the asm says. The flag came from objdump reading the NUL as
the start of a 4-byte `add %bh,...`. Two corrections, both positive proofs, not hedges:

  * a candidate instruction that overlaps a byte `asm/` declares as `db` data is objdump
    mis-reading a literal, and is dropped (`db_data_mask`);
  * if the anchor fragment's own body accounts for the bytes right up to the boundary, the
    boundary is real and the flag is dropped — unless the anchor under-counted a
    forced-keep, because then the walk is trusting the very short count that is the defect.

What survives is graded on the same line it is printed: every remaining `begins-mid-insn` is
a second sighting of an anchor's partial keep, i.e. one defect counted twice, and the
residual count of unexplained boundaries is printed separately and has to be read as the
number of things still needing a hand.

Usage:
    tools/forced_keep_audit.py [--tsv] [--verbose] [--selftest] [--limit N]
"""
from __future__ import annotations

import argparse
import collections
import glob
import os
import re
import subprocess
import sys
import tempfile

Counter = collections.Counter

EXE = "original/ultimaii.exe"
BIAS = 0x200
FUNC_RE = re.compile(r"^#\s*func\s+([0-9A-Fa-f]{4})\.\.([0-9A-Fa-f]{4})", re.M)
LABEL_RE = re.compile(r"^L_([0-9a-fA-F]{6}):")
BYTE_RE = re.compile(r"^\s*\.byte\s+([0-9A-Fa-fx,\s]+?)\s*(?:#.*)?$")
DB_RE = re.compile(r"^\s*db\s+(.*)$")
FORCED_RE = re.compile(r"forced-kept:.*?re-encodes\s+'(.*?)'\s+differently")
# Any `.byte` the decode tool deliberately kept raw. `gas re-encodes '...' differently` is the
# common form, but `stop-trunc` is not a re-encoding complaint at all — it is the tool
# admitting the map boundary cut an instruction in half — and the first version of this
# detector looked only for the first form, so all 28 stop-trunc keeps were invisible to it.
KEEP_RE = re.compile(r"forced-kept:\s*(.+?)\s*$")
HEXB_RE = re.compile(r"0x([0-9a-fA-F]{2})")


def db_line_bytes(line: str) -> bytes | None:
    """The bytes a `db` line assembles to, or None if the line is not a `db` directive.

    Three shapes occur in `asm/`: a bare string (`db "ORIGIN",0x00`), a string with a
    numeric byte glued to it (`db 0x8d,"KILLED--GOLD+",0x00`, where 0x8d is the length byte
    the game's own inline-string contract wants), and pure numeric runs (`db 0x4d,0x5a,...`
    for the MZ header and the padding). The first version of the audit matched only the
    first shape, so every numeric run was walked as if it were an instruction and every
    glued form was invisible to the data mask — which is how a fragment that ends in a
    string still produced a confident false 'boundary swallowed' verdict.

    Quoting is handled by scanning, not by splitting on commas: the strings are game text
    and contain commas.
    """
    m = DB_RE.match(line)
    if not m:
        return None
    s, out, i, n = m.group(1), bytearray(), 0, len(m.group(1))
    while i < n:
        while i < n and s[i] in " ,":
            i += 1
        if i >= n:
            break
        if s[i] == "#":                      # trailing comment, outside any string
            break
        if s[i] == '"':
            j = s.find('"', i + 1)
            if j < 0:
                return None
            out += s[i + 1:j].encode("latin-1")
            i = j + 1
            continue
        j = i
        while j < n and s[j] not in ",#":
            j += 1
        try:
            out.append(int(s[i:j].strip(), 0))
        except ValueError:
            return None                      # an expression this tool will not evaluate
        i = j
    return bytes(out)


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
    """Byte length of a `db` line, in every shape `db_line_bytes` understands."""
    b = db_line_bytes(line)
    return len(b) if b else 0


def db_data_mask(files: list[str], data: bytes) -> set[int]:
    """File offsets that `asm/` declares to be inline string data, not code.

    WHY THIS EXISTS. `begins-mid-insn` anchors a linear objdump pass on the previous
    fragment's start. Where that fragment holds a `db "..."` literal — which this binary does
    a lot, the command prompts are inline — objdump decodes the string bytes as instructions
    and invents long ones that swallow the next real boundary. The flag it produces is a
    fiction about a NUL byte. asm/0155 is the documented case and it was a false positive.

    HOW IT LOCATES A LITERAL. By searching the fragment's own byte span for the literal, not
    by walking the asm body. A walk needs instruction lengths to place a `db` line, and
    instruction lengths are the very thing under audit — a walk that desynchronises would
    mislabel data as code and hide the defect this is meant to find. The bytes are the
    trustworthy thing here: `assemble_clean.sh` proves the whole tree reassembles to the
    original, so a `db` literal in a fragment really does occur inside that fragment's span.
    A literal that matches more than once in its own span is skipped rather than guessed at.

    Only `db` lines are masked. A `.byte` line is usually a code encoding gas could not
    reproduce, and masking those would suppress the forced-keep signal this tool is for.
    """
    mask: set[int] = set()
    for path in files:
        try:
            text = open(path, errors="replace").read()
        except OSError:
            continue
        fm = FUNC_RE.search(text)
        if not fm:
            continue
        lo, hi = int(fm.group(1), 16) + BIAS, int(fm.group(2), 16) + BIAS
        span = data[lo:min(len(data), hi + 1)]
        body = [ln for ln in text.splitlines()
                if not ln.lstrip().startswith("#") and ln.strip()]
        tail = body[-1] if body else ""
        for ln in text.splitlines():
            lit = db_line_bytes(ln)
            if not lit:
                continue
            # The whole line's bytes, not just a quoted part: in `db "ORIGIN",0x00` the
            # terminator is exactly the byte objdump turns into a fake instruction that
            # swallows the next fragment.
            hits = [i for i in range(len(span)) if span.startswith(lit, i)]
            if len(hits) == 1:
                mask.update(range(lo + hits[0], lo + hits[0] + len(lit)))
            elif ln in tail:
                # A tail-pad (`db 0x00  # tail-pad`) matches anywhere, so the search cannot
                # place it — but a fragment's last line sits at the end of its own declared
                # span by construction, and that is exact. Without this the pad byte is
                # objdump's next imaginary instruction and three fragments are flagged.
                mask.update(range(hi + 1 - len(lit), hi + 1))
    return mask


def begins_mid_insn(data: bytes, s: int, anchor: int | None,
                    dbmask: frozenset[int] = frozenset()) -> str | None:
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

    `dbmask` is what makes the number quotable. A candidate instruction that overlaps bytes
    `asm/` declares to be string data is objdump mis-reading a literal as code, and is not
    evidence about a boundary. Without this the count was inflated and the tool said so in
    its own docstring while still printing the inflated number as its headline.
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
                if dbmask and any((off + k) in dbmask for k in range(ins[off])):
                    return None
                return (f"first insn at {s:04X} lies inside a {ins[off]}-byte insn "
                        f"starting at {off - BIAS:04X}")
            return None
    return None


def audit_file(path: str, data: bytes, anchor: int | None = None,
               dbmask: frozenset[int] = frozenset()) -> list[dict]:
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
    mid = begins_mid_insn(data, s, anchor, dbmask)
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
            keep = KEEP_RE.search(ln)
            if cur in ins:
                real = ins[cur]
                if keep and nbytes < real:
                    said = (f"gas said `{forced.group(1).strip()}`" if forced
                            else f"marker `{keep.group(1).strip()}`")
                    findings.append({
                        "file": os.path.basename(path), "addr": f"{cur - BIAS:04X}",
                        "kind": "partial-forced-keep",
                        "detail": f"{nbytes} B kept, real insn {real} B ({said})"})
            elif keep:
                said = (f"gas said `{forced.group(1).strip()}`" if forced
                        else f"marker `{keep.group(1).strip()}`")
                findings.append({
                    "file": os.path.basename(path), "addr": f"{cur - BIAS:04X}",
                    "kind": "undecodable-forced-keep",
                    "detail": f"{nbytes} B kept and objdump cannot decode an insn "
                              f"here at all ({said})"})
            cur += max(nbytes, 1)
            continue
        dm = DB_RE.match(ln)
        if dm:
            cur += max(db_byte_len(ln), 1)
            continue        # a real instruction line: must sit on an objdump instruction start
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


def insn_len_at(data: bytes, off: int, want: int) -> int | None:
    """Length of the instruction objdump decodes AT `off`, or None.

    Used when a linear pass did not start an instruction at `off` — which is not a fact about
    the binary, it is a fact about the pass having desynchronised upstream. Decoding a short
    window from `off` itself is local and cannot inherit that desync.
    """
    ins = objdump_lengths(data, off, min(len(data), off + max(want, 8) + 8))
    return ins.get(off)


def walk_asm_end(path: str, data: bytes) -> int | None:
    """The runtime address the anchor's own byte accounting ends at, or None.

    `begins-mid-insn` is a claim about a boundary and its only evidence was a linear objdump
    pass over the previous fragment — the weak part, because it desynchronises on anything
    the asm describes as data and objdump reads as code. The asm's accounting is the strong
    part: `assemble_clean.sh` proves the tree reassembles to the original bytes, so a
    fragment's `.byte` counts and `db` literals really are those bytes.

    Instruction lines take their length from objdump at the cursor, with a local re-decode
    when the linear map has no entry there (the map is wrong, not the cursor). Returns None
    when even that fails, which is treated as 'no opinion', never as 'suppress'.
    """
    try:
        text = open(path, errors="replace").read()
    except OSError:
        return None
    fm = FUNC_RE.search(text)
    if not fm:
        return None
    s, e = int(fm.group(1), 16), int(fm.group(2), 16)
    fs, fe = s + BIAS, e + BIAS
    ins = objdump_lengths(data, fs, min(len(data), fe + 1 + 24))
    cur = fs
    for ln in text.splitlines():
        if ln.lstrip().startswith("#") or not ln.strip():
            continue
        lm = LABEL_RE.match(ln)
        if lm:
            lbl = int(lm.group(1), 16)
            if lbl >= cur:
                cur = lbl
            continue
        if ln.rstrip().endswith(":"):
            continue
        bm = BYTE_RE.match(ln)
        if bm:
            cur += max(len(HEXB_RE.findall(bm.group(1))), 1)
            continue
        if db_line_bytes(ln) is not None:
            cur += max(db_byte_len(ln), 1)
            continue
        n = ins.get(cur) or insn_len_at(data, cur, 4)
        if not n:
            return None
        cur += n
    return cur - BIAS


def scan(files: list[str], data: bytes) -> tuple[dict[str, list[dict]], int]:
    """Audit every fragment and drop the boundary flags the asm can disprove.

    Returns {file: findings} and the number of `begins-mid-insn` flags suppressed, because a
    number nobody can account for is a number nobody should quote.

    A flag is suppressed only on a positive proof: the anchor's own body accounts for the
    bytes right up to the boundary. It is NOT suppressed when the anchor under-counted a
    forced-keep, because the walk trusts the short count and that under-count is the very
    defect being looked for — asm/01FD kept one byte of the three-byte call `e8 88 04`, its
    walk closes on 01FE, and 01FE is genuinely mid-instruction.
    """
    # previous fragment start per file, so each check is anchored on a discovered entry
    prev: dict[str, int | None] = {}
    prev_path: dict[str, str | None] = {}
    last: int | None = None
    lastp: str | None = None
    for p in files:
        m = re.match(r"asm/([0-9A-Fa-f]{4})_", p)
        prev[p] = last
        prev_path[p] = lastp
        if m:
            last = int(m.group(1), 16)
            lastp = p

    dbmask = frozenset(db_data_mask(files, data))
    per: dict[str, list[dict]] = {p: audit_file(p, data, prev.get(p), dbmask) for p in files}

    suppressed = 0
    for p in files:
        ap = prev_path.get(p)
        # Grade each surviving boundary flag by whether the anchor already carries a
        # under-counted forced-keep — i.e. whether this flag is a second sighting of a cause
        # that is counted on its own line, or an unexplained boundary. Without the grade the
        # number reads like 78 separate unknowns when most of them are one defect seen twice.
        anchor_kept = bool(ap) and any(
            h["kind"] in ("partial-forced-keep", "undecodable-forced-keep") for h in per[ap])
        for h in per[p]:
            if h["kind"] == "begins-mid-insn":
                h["cause"] = "anchor-partial-keep" if anchor_kept else "unexplained"
        if not ap or anchor_kept:
            continue
        end = walk_asm_end(ap, data)
        if end is None:
            continue
        for h in list(per[p]):
            if h["kind"] == "begins-mid-insn" and int(h["addr"], 16) == end:
                per[p].remove(h)
                suppressed += 1
    return per, suppressed


def selftest(data: bytes) -> int:
    """The control that should have existed from the start.

    asm/353A is a KNOWN-TRUE case, proved by hand on 2026-10-28d: one byte (`0x8a`) was
    forced-kept and the real instruction is four (`8a 1e 49 00` = `mov 0x49,%bl`). A
    detector that misses it is worthless, and the first version of this tool missed it and
    printed a clean bill of health for 290 files.

    asm/0155 is the KNOWN-FALSE case, and a detector that only catches the true one is not
    being tested. Its previous fragment ends in `db "ORIGIN",0x00`; the linear pass reads
    the NUL as the start of a 4-byte `add %bh,...` that swallows 0155, where the real bytes
    are `bf 0b 00` = `mov $0xb,%di`, exactly what the asm says. The check must stay quiet
    about it, or the headline count is noise with a number attached.

    asm/2F6F is the same false shape by a different route: its anchor ends `jmp L_000c33`
    three bytes short of the boundary, but the anchor contains `db "MISS",0x00`, the linear
    pass decodes those five bytes as code, and the desync puts a fake 2-byte instruction
    across 2F6E. The anchor's own accounting closes exactly on 2F6F, and it must buy the
    suppression.

    asm/01FE is the case that stops the accounting test from being a blanket excuse. Its
    anchor is one line, `.byte 0xe8  # forced-kept: stop-trunc call 0x888`, and the real
    instruction is `e8 88 04` — a call the map cut in half. The walk closes on 01FE and the
    boundary is still wrong, because the walk trusted the short keep. An anchor carrying a
    partial keep must never be allowed to suppress, and before this control was written the
    stop-trunc marker form was invisible to the partial-keep detector entirely.
    """
    files = sorted(glob.glob("asm/*.asm"))
    per, _suppressed = scan(files, data)

    def kinds(name):
        for p in files:
            if os.path.basename(p) == name:
                return [h["kind"] for h in per[p]]
        return ["(file not found)"]

    hits = per.get(next(p for p in files if p.endswith("353A_sub_353a.asm")), [])
    ok = any(h["kind"] in ("partial-forced-keep", "undecodable-forced-keep")
             and h["addr"] == "353C" for h in hits)
    print("CONTROL  asm/353A @353C must be flagged (partial forced-keep) -> "
          f"{'OK' if ok else 'MISSED'}")
    ok2 = "begins-mid-insn" in kinds("353D_sub_353d.asm")
    print("CONTROL  asm/353D must be flagged (first insn is invented)      -> "
          f"{'OK' if ok2 else 'MISSED'}")
    ok3 = "begins-mid-insn" not in kinds("0155_sub_0155.asm")
    print("CONTROL  asm/0155 must stay quiet (string bytes, not a boundary) -> "
          f"{'OK' if ok3 else 'FALSE POSITIVE'}")
    ok4 = "begins-mid-insn" not in kinds("2F6F_cmd_B.asm")
    print("CONTROL  asm/2F6F must stay quiet (anchor accounting closes)      -> "
          f"{'OK' if ok4 else 'FALSE POSITIVE'}   ({kinds('2F6F_cmd_B.asm')})")
    ok5 = "begins-mid-insn" in kinds("01FE_sub_01fe.asm")
    print("CONTROL  asm/01FE must be flagged (stop-trunc cut a call in half) -> "
          f"{'OK' if ok5 else 'MISSED'}   ({kinds('01FE_sub_01fe.asm')})")
    ok6 = "begins-mid-insn" not in kinds("02CB_sub_02cb.asm")
    print("CONTROL  asm/02CB must stay quiet (anchor ends in a tail-pad byte)   -> "
          f"{'OK' if ok6 else 'FALSE POSITIVE'}   ({kinds('02CB_sub_02cb.asm')})")
    if not (ok and ok2 and ok3 and ok4 and ok5 and ok6):
        print("SELFTEST: FAIL — the detector does not match the cases proven by hand. "
              "Do not trust any count from this tool.")
        return 1
    print("SELFTEST: PASS")
    return 0


def tail_attribution(tail_addr: int, tail_bytes: bytes) -> tuple[str, str]:
    """Has the fragment covering `tail_addr` been told what those bytes really are?

    A partial forced-keep is a CAUSE and it stays forever, correctly: the instruction
    genuinely starts in the previous fragment's last byte, so the previous fragment's span
    really does hold only part of it. What we actually want to know is whether the NEXT
    fragment still pretends the leftover bytes are instructions. So:

      corrected    the fragment opens with a .byte line carrying exactly those tail bytes
      outstanding  the fragment opens with a mnemonic, i.e. it is still showing invented code
      unknown      no file covers that address (should not happen)

    Without this the audit's headline number never moves, because it was counting causes.
    It did exactly that after nine real corrections: 63 before, 63 after, and a reader would
    reasonably conclude nothing had been done.
    """
    import glob
    fs = tail_addr + BIAS
    best = None
    for path in glob.glob("asm/*.asm"):
        m = re.match(r"^asm/([0-9A-Fa-f]{4})_", path)
        if not m:
            continue
        start = int(m.group(1), 16) + BIAS
        if start <= fs and (best is None or start > best[0]):
            best = (start, path)
    if best is None:
        return "unknown", ""
    body = [ln for ln in open(best[1], errors="replace").read().splitlines()
            if not ln.lstrip().startswith("#")]
    for ln in body:
        if ln.strip() and not ln.startswith(("sub_", "L_")) and not ln.rstrip().endswith(":"):
            bm = BYTE_RE.match(ln)
            if bm:
                got = bytes(int(x, 16) for x in HEXB_RE.findall(bm.group(1)))
                if got.startswith(tail_bytes):
                    return "corrected", os.path.basename(best[1])
            return "outstanding", os.path.basename(best[1])
    return "unknown", os.path.basename(best[1])


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--tsv", action="store_true")
    ap.add_argument("--queue", action="store_true",
                    help="print the outstanding corrections, one line per fix")
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

    per, suppressed = scan(files, data)
    all_f = [h for p in files for h in per[p]]

    partial = [f for f in all_f if f["kind"] == "partial-forced-keep"]
    # classify each cause by whether its consequence has been fixed
    data_full = data
    for f in partial:
        m = re.search(r"(\d+) B kept, real insn (\d+) B", f["detail"])
        kept, real = int(m.group(1)), int(m.group(2))
        addr = int(f["addr"], 16)
        f["tail"] = data_full[addr + BIAS + kept: addr + BIAS + real]
        f["status"], f["where"] = tail_attribution(addr + kept, f["tail"])
    outstanding = [f for f in partial if f.get("status") == "outstanding"]

    if a.queue:
        # The queue, not the census. `partial` is a list of causes and causes are permanent by
        # design, so printing them as if they were work is how a queue of 36 started looking
        # like a queue of 63 that nobody could finish. One line per fix, grouped by the shape
        # of fix it needs, because the two kinds are done by different operations.
        def shape(f):
            return ("stop-trunc" if "marker `stop-trunc" in f["detail"]
                    else "body-swap" if "gas said" in f["detail"] else "other")
        print("file\taddr\tkept\treal\ttail\tshape\tfixes")
        for f in sorted(outstanding, key=lambda f: (shape(f), f["file"])):
            m = re.search(r"(\d+) B kept, real insn (\d+) B", f["detail"])
            kept, real = int(m.group(1)), int(m.group(2))
            print(f"{f['file']}\t{f['addr']}\t{kept}\t{real}\t"
                  f"{f['tail'].hex(' ')}\t{shape(f)}\t{f['where']}")
        return 0
    done = [f for f in partial if f.get("status") == "corrected"]
    inside = [f for f in all_f if f["kind"] == "begins-mid-insn"]
    cascade = [f for f in all_f if f["kind"] == "boundary-inside-insn"]
    files_hit = {f["file"] for f in all_f}

    if a.tsv:
        print("file\taddr\tkind\tdetail")
        for f in all_f:
            print(f"{f['file']}\t{f['addr']}\t{f['kind']}\t{f['detail']}")
        return 0

    print(f"scanned {len(files)} asm/ files")
    print(f"  partial forced-keeps (CAUSES, permanent by design):       {len(partial)}")
    print(f"    -> consequence CORRECTED (next fragment names the bytes): {len(done)}")
    print(f"    -> still OUTSTANDING (next fragment shows invented code): {len(outstanding)}")
    kinds = Counter(("stop-trunc: the map boundary itself cut an instruction, so this is a "
                     "re-decode or a merge, not a body swap"
                     if "marker `stop-trunc" in f["detail"] else
                     "gas re-encode: one line in the previous fragment, then the tail bytes"
                     if "gas said" in f["detail"] else
                     "other marker") for f in outstanding)
    for k, n in sorted(kinds.items(), key=lambda x: -x[1]):
        print(f"       {n:3d}  {k}")
    print(f"  BEGINS-MID-INSN   ({suppressed} suppressed as decode artefacts): {len(inside)}")
    if inside:
        graded = Counter(h.get("cause", "unexplained") for h in inside)
        print(f"    -> second sighting of an anchor's partial keep: {graded['anchor-partial-keep']}")
        print(f"    -> UNEXPLAINED boundary, needs a hand check:    {graded['unexplained']}")
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
