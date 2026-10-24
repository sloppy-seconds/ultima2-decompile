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
ITEM = re.compile(r'"((?:[^"\\]|\\.)*)"|0x([0-9A-Fa-f]{2})')
MIN_LEN = 3


def db_bytes(s):
    """Decode a db/.byte operand into the raw bytes it emits."""
    out = bytearray()
    for m in ITEM.finditer(s):
        if m.group(1) is not None:
            out.extend(m.group(1).encode('latin1'))
        else:
            out.append(int(m.group(2), 16))
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

    So search the declared function window (widened, because `# func` ends are approximate --
    `asm/0A02` declares 0A14 for a string that runs to 0A16) and accept the hit only if it is
    unique. Ambiguous or absent means unproven, and unproven entries are dropped, not guessed.
    """
    if start is None:
        return None
    lo = max(0, start + BIAS)
    hi = min(len(exe), end + BIAS + 256)
    hits, i = [], exe.find(raw, lo, hi)
    while i != -1:
        hits.append(i)
        i = exe.find(raw, i + 1, hi)
    return hits[0] if len(hits) == 1 else None


def parse(path, exe=None):
    """Return (fname, start, end, evidence, [(file_off, text)])."""
    fname = os.path.basename(path)[:-4]
    lines = open(path, errors='replace').read().splitlines()
    start = end = None
    evidence = ''
    # index the labels so each db can find the next one
    labelled = [(i, int(m.group(1), 16))
                for i, ln in enumerate(lines) if (m := LABEL_RE.match(ln))]
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
        operand = m.group(1) if m.group(1) is not None else m.group(2)
        raw = db_bytes(operand)
        if not raw:
            continue
        nxt = [a for i, a in labelled if i > idx]
        if nxt:
            base = nxt[0] - len(raw)      # the db is the last thing before that label
        else:
            base = exe_anchor(exe, raw, start, end) if exe is not None else None
            if base is None:
                continue
        for off, text in printable_runs(raw):
            out.append((base + off, text))
    return fname, start, end, evidence, out


def build(exe=None):
    rows = []
    if exe is None:
        exe = open(EXE, 'rb').read()
    for p in sorted(glob.glob('asm/*.asm')):
        fname, start, end, evidence, strings = parse(p, exe)
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
                         'runtime': foff - BIAS, 'text': text})
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
    for r in sorted(rows, key=lambda x: x['foff']):
        span = '%04X..%04X' % (r['start'], r['end']) if r['start'] is not None else '?'
        print('file:%06X  runtime:%04X  %-34s [%s]'
              % (r['foff'], r['runtime'], r['file'], span))
        print('        %r' % r['text'])
        print('        owner evidence: %s' % (r['evidence'] or '(none recorded)'))
    print('\n%d strings in %d functions' % (len(rows), len({r['file'] for r in rows})))


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
