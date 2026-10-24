#!/usr/bin/env python3
"""strings_atlas.py — every embedded string, with the function that owns it.

Why this exists: at least three wrong claims in this project came from reading a bare
string next to an address and inventing a story about it. Two adjacent spell catalogues
were assumed to be two town variants (they were the cleric shrine and the wizard shop);
a commerce attribution was nearly "corrected" into error by mixing the two address bases.
A string printed without its owner invites exactly that. So this never prints a string
without naming the routine that contains it, and prints that routine's own
`name-evidence` line, which is the reason the routine has its name.

Address bases (docs/decompiling.md § address bases) — the trap this tool exists to kill:
  * `asm/` FILENAMES are RUNTIME offsets.
  * `L_xxxxxx` LABELS inside them are FILE offsets.
  * file = runtime + 0x200.
Every string is printed with BOTH, labelled, so a reader cannot silently mix them.

Locating a string. Inline messages sit in the middle of code: a `call L_0051df`
(str_out) is immediately followed by `db "...",0x00`. The `db` is the last thing the
clean wave emits before the next label, so the byte offset of its first operand is
`next_label - byte_count`. That is measured from the listing itself and does not
assume an instruction width, which matters because the preceding instruction is a
3-byte near call in most places and something else in several.

One `db` line can hold several NUL-separated strings (`asm/4C50` has nineteen on one
line), so each printable run is reported separately with its own offset. Messages are
also wrapped in 0x8D/0x0D control bytes on both ends -- the same thing that made
`tools/cfg_printed.py` silently drop `LEGS PARALIZED!` -- so control bytes are skipped
rather than folded into the text.

Usage:
    python3 tools/strings_atlas.py                    # everything
    python3 tools/strings_atlas.py --grep SPELL       # substring filter
    python3 tools/strings_atlas.py --owner 19D7       # one function
    python3 tools/strings_atlas.py --selftest         # control: the two spell lists
    python3 tools/strings_atlas.py --verify           # check offsets against the exe
"""
import argparse
import glob
import os
import re
import sys

BIAS = 0x200                      # file = runtime + 0x200
EXE = 'original/ultimaii.exe'
FUNC_RE = re.compile(r'^#\s*func\s+([0-9A-Fa-f]{4})\.\.([0-9A-Fa-f]{4})')
NAME_RE = re.compile(r'^#\s*name-evidence:\s*(.*)')
LABEL_RE = re.compile(r'^L_([0-9a-fA-F]{6}):')
DB_RE = re.compile(r'^\s*\.?byte\s+(.*)$|^\s*db\s+(.*)$')
ITEM = re.compile(r'"((?:[^"\\]|\\.)*)"|0x([0-9A-Fa-f]{2})|(\d+)')
MIN_LEN = 3
END_SLACK = 4        # a trailing db may finish this many bytes past the declared # func end
STR_OUT_FILE = 0x51DF          # file offset of the printer's entry (the L_0051df label)
WRAPPERS = (0x8D, 0x0D)


def str_out_sites(exe):
    """File offsets of the byte after every near `call` to the string printer.

    This is the strongest string evidence in the project and it does not care how `asm/`
    renders anything: `call str_out` and the bytes after the return address ARE the message,
    because that is the printer's calling convention (the same contract the Apple II side has
    with `JSR $4006`, docs/apple2-reference.md § 4). Enumerated from the executable alone.
    """
    out = []
    for i in range(len(exe) - 3):
        if exe[i] == 0xE8 and \
           i + 3 + int.from_bytes(exe[i + 1:i + 3], 'little', signed=True) == STR_OUT_FILE:
            out.append(i + 3)
    return out


def message_at(exe, off):
    """The message a str_out call prints: skip control wrappers, read to the NUL."""
    j = off
    while j < len(exe) and exe[j] in WRAPPERS:
        j += 1
    k = j
    while k < len(exe) and exe[k] != 0:
        k += 1
    raw = exe[j:k]
    if len(raw) < MIN_LEN or not all(0x20 <= c <= 0x7E for c in raw):
        return None
    return j, raw.decode('latin1')


def owner_of(ranges, foff):
    """The asm/ file whose declared # func range contains this file offset."""
    best = None
    for lo, hi, fname, evidence in ranges:
        if lo <= foff < hi:
            best = (fname, evidence)
    return best


def strip_comment(s):
    """Drop a trailing `# ...` that is outside a quoted string.

    `db "-WHAT?",0          # string (NUL at 0x356c)` — the operand is `"-WHAT?",0` and the
    rest is a note. Decoding the whole line instead made the byte stream pick up `0x35` and `6`
    out of the address in the comment, so the run came out two bytes long and its anchor missed.
    The hex form of this bug predates the decimal one: `0x356c` matched `0x35` even before bare
    decimals were accepted. A `#` inside quotes is data, so quote state has to be tracked.
    """
    out = []
    in_str = False
    for ch in s:
        if ch == '"':
            in_str = not in_str
        elif ch == '#' and not in_str:
            break
        out.append(ch)
    return ''.join(out)


def db_bytes(s):
    """Decode a db/.byte operand into the raw bytes it emits.

    Three operand shapes appear in the tree, and the third was missed until it cost nine
    strings: quoted text, `0xNN` hex, and **bare decimal** `0` — the clean wave writes
    `db "TRANSACT-",0` in some files and `db "MALE",0x00` in others, and the decimal form
    decoded as a nine-byte string with no terminator. That put the base one byte early
    against the next label and then the byte-exactness filter in build() dropped the string
    as unverifiable, which is the silent kind of wrong: no error, just a missing row.
    """
    out = bytearray()
    for m in ITEM.finditer(strip_comment(s)):
        if m.group(1) is not None:
            out.extend(m.group(1).encode('latin1'))
        elif m.group(2) is not None:
            out.append(int(m.group(2), 16))
        else:
            out.append(int(m.group(3)) & 0xFF)
    return bytes(out)


def printable_runs(raw):
    """Every maximal 0x20..0x7E run of MIN_LEN+, as (offset_within_raw, text)."""
    runs, i = [], 0
    while i < len(raw):
        if 0x20 <= raw[i] <= 0x7E:
            j = i
            while j < len(raw) and 0x20 <= raw[j] <= 0x7E:
                j += 1
            if j - i >= MIN_LEN:
                runs.append((i, raw[i:j].decode('latin1')))
            i = j
        else:
            i += 1
    return runs


def exe_anchor(exe, raw, start, end):
    """Locate a trailing `db` by searching the executable for its exact bytes.

    The next-label rule cannot work for the last `db` in a file: there is no label after it.
    That is not a corner case, it is 232 of the 600-odd files in `asm/` -- including
    `asm/0A02_invalid_move_msg`, whose only string was silently missing from the atlas. A
    tool that drops a documented string because of where it sits in a listing is the failure
    mode this file exists to prevent.

    So search the declared function window and accept a hit only if it lands where a trailing
    `db` must land: the `db` is the LAST thing the clean wave emitted before the next label,
    so it ends at or just past the declared function end. `# func` ends are approximate --
    `asm/0A02` declares 0A14 for a string that runs to 0A16, `asm/5066` declares 506D for one
    that runs to 506E -- so allow END_SLACK bytes past it and accept only a hit inside that
    band.

    Proximity, not uniqueness, and only where proximity is needed. The first version required a
    unique hit in a 256-byte window and dropped anything ambiguous -- which silently discarded
    short strings that `asm/` had rendered perfectly well as `db`, `MALE` in
    `asm/5066_print_sex_male` and `PASS` in `asm/08FF_sub_08ff` among them, because `MALE\0`
    and `PASS\0` each occur twice nearby. Nine real strings lost to an over-strict guard, and
    from the outside every one of them looked like a classification problem in `asm/`.

    The second version made the band the only rule and that was its own regression: four
    strings a unique wide hit had been anchoring correctly (`CAST-`, `DESCEND`, and two in the
    cmd_M printer) fell outside END_SLACK and vanished, because a declared `# func` end can sit
    well past the real content -- `asm/8DCD` declares 8DCD..8FFF for a seven-byte routine and
    zero pad. So the band is a TIE-BREAKER, not a gate: one hit anywhere in the window is
    accepted on its own, and the band only decides when there is more than one. Ambiguity that
    survives the band is still dropped -- a narrow verified answer beats a broad guess.
    """
    if start is None:
        return None
    lo = max(0, start + BIAS)
    hi = min(len(exe), end + BIAS + 256)
    declared_end = end + BIAS
    hits = []
    i = exe.find(raw, lo, hi)
    while i != -1:
        hits.append(i)
        i = exe.find(raw, i + 1, hi)
    if len(hits) == 1:
        return hits[0]
    if len(hits) > 1:
        near = [h for h in hits if abs((h + len(raw)) - declared_end) <= END_SLACK]
        if len(near) == 1:
            return near[0]
    return None


def _data_line_runs(lines):
    """Group the indices of consecutive data lines into runs.

    Two `db`/`.byte` lines are in the same run when nothing but blank lines and `#` comments
    separates them. This exists because the base-address rule assumed a run of one: the db is
    the last thing before the next label, so `base = next_label - len(raw)`. When a forced-keep
    `.byte` filler line follows the string — which is what the clean wave emits when gas would
    re-encode an instruction differently — the string is no longer last, and the computed base
    lands short by the filler's length. That silently dropped `TRANSACT-` in the merged
    `asm/4050_cmd_T` and `-WHAT?` in `asm/334D_cmd_D`: both rendered correctly as data, both
    invisible to the atlas, and both looked exactly like a classification gap from the outside.
    """
    idxs = []
    for i, ln in enumerate(lines):
        if ln.strip().startswith('#') or not ln.strip():
            continue
        if DB_RE.match(ln):
            idxs.append(i)
    runs, cur = [], []
    for i in idxs:
        if cur and all((not lines[j].strip()) or lines[j].strip().startswith('#')
                       for j in range(cur[-1] + 1, i)):
            cur.append(i)
        else:
            if cur:
                runs.append(cur)
            cur = [i]
    if cur:
        runs.append(cur)
    return runs


def parse(path, exe=None):
    """Return (fname, start, end, evidence, [(file_off, text)])."""
    fname = os.path.basename(path)[:-4]
    lines = open(path, errors='replace').read().splitlines()
    start = end = None
    evidence = ''
    # index the labels so each db can find the next one
    labelled = [(i, int(m.group(1), 16))
                for i, ln in enumerate(lines) if (m := LABEL_RE.match(ln))]
    # pre-pass: decode every data line, then work out where each run of them starts.
    # A run is anchored by the label that follows the WHOLE run, not by the line after each
    # db — see _data_line_runs.
    raws = {}
    for idx, line in enumerate(lines):
        m = DB_RE.match(line)
        if not m:
            continue
        operand = m.group(1) if m.group(1) is not None else m.group(2)
        r = db_bytes(operand)
        if r:
            raws[idx] = r
    bases = {}
    for run in _data_line_runs(lines):
        run = [i for i in run if i in raws]
        if not run:
            continue
        nxt = [a for i, a in labelled if i > run[-1]]
        if nxt:
            total = sum(len(raws[i]) for i in run)
            addr = nxt[0] - total
            for i in run:
                bases[i] = addr
                addr += len(raws[i])
        else:
            # No `L_xxxxxx` label follows the run at all. That happens in the files the 2026-10-23
            # merges rewrote with `.Lname:` local labels, which carry no address and so cannot
            # anchor anything — `asm/334D_cmd_D` is one. Anchor the WHOLE run against the exe
            # rather than each line: a 10-byte concatenation is far more likely to be unique
            # than the 7-byte string on its own, and the per-line offsets then fall out of the
            # run's own lengths instead of being guessed one line at a time.
            joined = b''.join(raws[i] for i in run)
            at = exe_anchor(exe, joined, start, end) if exe is not None else None
            for i in run:
                bases[i] = at
                if at is not None:
                    at += len(raws[i])
            continue
    out = []
    for idx, line in enumerate(lines):
        m = FUNC_RE.match(line.strip())
        if m:
            start, end = int(m.group(1), 16), int(m.group(2), 16)
            continue
        m = NAME_RE.match(line.strip())
        if m:
            evidence = m.group(1).strip()
            continue
        m = DB_RE.match(line)
        if not m:
            continue
        raw = raws.get(idx)
        if not raw:
            continue
        base = bases.get(idx, 'unset')
        if base is None:
            base = exe_anchor(exe, raw, start, end) if exe is not None else None
            if base is None:
                continue
        elif base == 'unset':
            continue
        for off, text in printable_runs(raw):
            out.append((base + off, text))
    return fname, start, end, evidence, out


def build(exe=None):
    rows = []
    ranges = []
    if exe is None:
        exe = open(EXE, 'rb').read()
    for p in sorted(glob.glob('asm/*.asm')):
        fname, start, end, evidence, strings = parse(p, exe)
        if start is not None:
            ranges.append((start + BIAS, end + BIAS, fname, evidence))
        for foff, text in strings:
            end = foff + len(text)
            # A real inline message is terminated by a control byte. This filter is
            # not cosmetic: without it the tool reports 474 "strings" of which 235 are
            # mis-decoded data -- the clean wave rendered string blobs as `.byte`
            # instruction sequences (asm/15E1 lines 196+ and asm/0720 are the worst),
            # and each printable fragment inside them looks like a short message.
            # The terminator set is {0x00, 0x8D, 0x0D}: 0x00 ends a message, and
            # 0x8D/0x0D separate the lines *inside* one multi-line message, so
            # `4-PASS 5-SURFACE, 6-PRAYER.` is followed by 0x8D and not by 0x00.
            # Accepting all three keeps 336 strings and every one of them verifies
            # byte-exactly against the exe; 0x00 alone would keep 239 and silently
            # lose both spell catalogues, which is the exact regression --selftest
            # is there to catch. Unproven entries are dropped, not flagged: a tool
            # that prints a plausible wrong string is the failure mode this file
            # exists to avoid.
            if end >= len(exe) or exe[end] not in (0x00, 0x8D, 0x0D):
                continue
            if exe[foff:end].decode('latin1', 'replace') != text:
                continue
            rows.append({'file': fname, 'start': start, 'end': end,
                         'evidence': evidence, 'foff': foff,
                         'runtime': foff - BIAS, 'text': text,
                         'source': 'db-line'})
    # Second source: the printer's own calling convention. Nine messages sit in spans `asm/`
    # renders as instructions, so no amount of parsing listings will ever report them -- and
    # `asm_body_guard` forbids editing those body lines to make them visible, which is a
    # decision about the tree's invariant rather than a cleanup. The contract does not care
    # about the rendering, so the atlas no longer does either. Rows are tagged so a reader can
    # see which kind of evidence each one rests on; both kinds are verified byte-exactly
    # against the executable by verify().
    seen = {(r['foff'], r['text']) for r in rows}
    for site in str_out_sites(exe):
        m = message_at(exe, site)
        if m is None:
            continue
        foff, text = m
        if (foff, text) in seen:
            continue
        seen.add((foff, text))
        owner = owner_of(ranges, foff)
        rows.append({'file': owner[0] if owner else '?',
                     'start': None, 'end': foff + len(text),
                     'evidence': (owner[1] if owner else '') or '(no name-evidence recorded)',
                     'foff': foff, 'runtime': foff - BIAS, 'text': text,
                     'source': 'str-out-contract'})
    return rows


def verify(rows):
    """Every reported offset must actually hold its text in the executable.

    build() already applies this as a filter, so a non-zero return here means the
    filter itself broke rather than that some string is mislocated.
    """
    exe = open(EXE, 'rb').read()
    ok = bad = 0
    misses = []
    for r in rows:
        raw = exe[r['foff']:r['foff'] + len(r['text'])]
        if raw.decode('latin1', 'replace') == r['text']:
            ok += 1
        else:
            bad += 1
            if len(misses) < 8:
                misses.append('%s foff 0x%05X %r != %r'
                              % (r['file'], r['foff'], r['text'][:28], raw[:28]))
    print('%d/%d strings land exactly on their own bytes in %s' % (ok, ok + bad, EXE))
    for m in misses:
        print('  MISS ' + m)
    return 0 if bad == 0 else 1


def show(rows):
    from collections import Counter
    for r in sorted(rows, key=lambda x: x['foff']):
        span = '%04X..%04X' % (r['start'], r['end']) if r['start'] is not None else 'contract-only'
        print('file:%06X  runtime:%04X  %-34s [%s]  %s'
              % (r['foff'], r['runtime'], r['file'], span, r.get('source', 'db-line')))
        print('        %r' % r['text'])
        print('        owner evidence: %s' % (r['evidence'] or '(none recorded)'))
    kinds = Counter(r.get('source', 'db-line') for r in rows)
    print('\n%d strings in %d functions (%s)'
          % (len(rows), len({r['file'] for r in rows}),
             ', '.join('%s=%d' % kv for kv in sorted(kinds.items()))))


def selftest():
    """Control: the two spell catalogues must resolve to DIFFERENT owners.

    This is the exact mistake the tool exists to prevent. A first pass read two
    6-spell lists and called them two town variants; they are the cleric shrine and
    the wizard shop, and the owner attribution is what says so. If the extractor
    loses either list the control fails, so a silent regression cannot pass.
    """
    rows = build()
    cleric = [r for r in rows if '4-PASS' in r['text']]
    wizard = [r for r in rows if '4-M.M.' in r['text']]
    bad = 0
    if not cleric:
        print('SELFTEST FAIL: the cleric spell catalogue was not extracted at all')
        bad += 1
    if not wizard:
        print('SELFTEST FAIL: the wizard spell catalogue was not extracted at all')
        bad += 1
    if bad:
        return 1
    c = {r['file'] for r in cleric}
    w = {r['file'] for r in wizard}
    if not any(f.startswith('1869') for f in c):
        print('SELFTEST FAIL: cleric list attributed to %s, expected asm/1869_*' % sorted(c))
        bad += 1
    if not any(f.startswith('19D7') for f in w):
        print('SELFTEST FAIL: wizard list attributed to %s, expected asm/19D7_*' % sorted(w))
        bad += 1
    if c & w:
        print('SELFTEST FAIL: both catalogues attributed to %s' % sorted(c & w))
        bad += 1
    if verify(build()) != 0:
        print('SELFTEST FAIL: some reported offsets do not hold their own bytes')
        bad += 1
    if len(build()) < 300:
        print('SELFTEST FAIL: only %d strings extracted -- the filter is eating real '
              'messages, not just mis-decoded data' % len(build()))
        bad += 1
    # The contract source must be live. Nine messages sit in spans asm/ renders as instructions,
    # and asm_body_guard forbids editing those body lines, so the contract is the ONLY thing
    # that carries them. If it contributes nothing the atlas is blind to them again -- and this
    # time nothing downstream would notice, which is the whole reason for the control.
    contract = [r for r in rows if r.get('source') == 'str-out-contract']
    if not contract:
        print('SELFTEST FAIL: the str-out contract source contributes nothing -- the atlas is '
              'blind to every message asm/ does not render as data')
        bad += 1
    # Every contract row must be a real print site, not a guess: the byte range has to be
    # adjacent to a `call str_out`, and it has to hold its own bytes (verify() covers the
    # second half for all rows).
    exe = open(EXE, 'rb').read()
    sites = set(str_out_sites(exe))
    stray = [r for r in contract if not any(abs(r['foff'] - s) <= 2 for s in sites)]
    if stray:
        print('SELFTEST FAIL: %d contract rows are not adjacent to a str_out call site' % len(stray))
        bad += 1
    if any(r['source'] == 'str-out-contract' and r['file'] == '?' for r in rows):
        print('NOTE: some contract rows have no owning asm/ file -- no # func range claims them')
    if bad:
        return 1
    print('SELFTEST PASS: cleric catalogue -> %s, wizard catalogue -> %s, and every '
          'offset verifies against the executable' % (sorted(c), sorted(w)))
    return 0


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument('--grep')
    ap.add_argument('--owner')
    ap.add_argument('--selftest', action='store_true')
    ap.add_argument('--verify', action='store_true')
    a = ap.parse_args()
    if a.selftest:
        return selftest()
    rows = build()
    if a.verify:
        return verify(rows)
    if a.grep:
        g = a.grep.upper()
        rows = [r for r in rows if g in r['text'].upper()]
    if a.owner:
        o = a.owner.upper()
        rows = [r for r in rows if r['file'].upper().startswith(o)]
    show(rows)
    return 0


if __name__ == '__main__':
    sys.exit(main())
