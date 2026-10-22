#!/usr/bin/env python3
"""fragment_splits.py — find routines the mechanical clean wave cut into pieces.

THE PATHOLOGY
-------------
The Phase 3 clean wave gave every CFG-discovered basic block its own `asm/` file and
its own row in `disasm/function-map.tsv`. That produces a *correct byte proof* and a
*wrong function map*. Real routines show up as a run of adjacent fragments where each
fragment ends on a branch into the next, only the first has an inbound `call`, and the
whole run contains exactly one `ret`.

This was found by hand in the commerce region (docs/g22-split-proposal.md), merged
under the owner's ruling, and then the identical shape turned up again, unrelated,
while decoding a number printer: `51A5/51A9/51AE` and `53B5/53C5` are two routines
drawn as five files. Hand-discovery does not scale and it only finds the ones you
trip over. This detects the shape.

WHAT IT REPORTS, AND WHAT IT DOES NOT
-------------------------------------
It reports **candidates**. It never merges anything. A function boundary is a claim
about intent, and the bytes support that claim only sometimes: a fragment whose tail
branches into its neighbour might be half of one routine, or might be a shared tail
that many routines jump into. AGENTS.md § 3 -- a wrong name is worse than no name, and
the same goes for a wrong boundary.

THE RULE
--------
Row B, immediately following row A in address order, is **glued** to A when all of:

  1. nothing `call`s any address in B (B has no entry point of its own);
  2. every jump landing inside B comes from A or from inside B -- no third party
     branches into B, which is what would make B a real shared target;
  3. A does not terminate on its own: A's last instruction is not `ret` and not an
     unconditional `jmp` to somewhere outside the A+B span.

A maximal run of glued rows is a **candidate** only when it contains **exactly one
`ret` and that `ret` is in the last row**. That condition is what separates a routine
that was cut up from a chain of fragments that merely never returns: on the first run
of this tool the commerce print chain `1799..17DC` came back as a candidate and did not
should have -- four fragments, no `ret` anywhere, a sequence of message printers that
tail into each other. Real and interesting, but a different claim from "this was one
function". Runs with zero rets are counted separately as `tail-chains` and not reported
as candidates.

Within candidates: if the first row has an inbound `call` the grade is `strong`; without
one it is `probable`, because the real entry may be a jump-table slot (this game reaches
its command handlers with `jmp *%bx`, which is invisible statically -- see AGENTS.md § 4)
or may simply sit outside the corpus.

CONTROLS -- run these before believing any output
-------------------------------------------------
`--selftest` asserts both directions against cases already settled by hand:

  POSITIVE  51A5/51A9/51AE and 53B5/53C5 must come back as candidates. They were
            decoded manually on 2026-10-23 and are certainly split.
  NEGATIVE  15E1 (tavern menu) and 1799 (food price) are single-file routines with
            their own entry and must NOT be flagged. And 2028 / 2052 / 20AB, merged
            on 2026-10-23, must no longer be flagged -- if they come back, the
            detector is keying on something other than the merge it already did.

A detector that flags everything fails this test, which is the point.

Usage:
    python3 tools/fragment_splits.py                 # report
    python3 tools/fragment_splits.py --selftest      # controls
    python3 tools/fragment_splits.py --tsv           # machine-readable
"""
from __future__ import annotations

import argparse
import collections
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MAP = os.path.join(ROOT, 'disasm', 'function-map.tsv')
ASMDIR = os.path.join(ROOT, 'asm')

BIAS = 0x200                      # file offset = runtime + 0x200
LABEL_RE = re.compile(r'^([A-Za-z_][A-Za-z_0-9.]*):')
L_HEX_RE = re.compile(r'^L_0*([0-9a-fA-F]{1,6})$')
SUB_HEX_RE = re.compile(r'^sub_([0-9a-fA-F]{4})$')
TARGET_RE = re.compile(r'\bL_0*([0-9a-fA-F]{1,6})\b')
JUMPS = {'jmp', 'jne', 'je', 'jb', 'jae', 'jns', 'js', 'ja', 'jge',
         'jle', 'jl', 'jbe', 'jo', 'jg', 'jc', 'jnc'}
UNCOND = {'jmp'}


def parse_asm_dir():
    """Return per-runtime-address facts and the global edge sets.

    Only lines the assembler sees matter; '#' lines are headers and are skipped, which
    is the same rule engine/tests/asm_body_guard.py uses.
    """
    calls = set()                 # runtime targets of `call`
    jumps = {}                    # runtime from -> list of runtime to
    rets = set()                  # runtime addresses of `ret`
    mnem_at = {}                  # runtime -> mnemonic (last writer wins)
    for fn in sorted(os.listdir(ASMDIR)):
        if not fn.endswith('.asm'):
            continue
        addr = None
        for raw in open(os.path.join(ASMDIR, fn), errors='replace'):
            line = raw.rstrip('\n')
            if not line.strip() or line.lstrip().startswith('#'):
                continue
            stripped = line.strip()
            m = LABEL_RE.match(stripped)
            if m and stripped.endswith(':'):
                name = m.group(1)
                lm = L_HEX_RE.match(name) or SUB_HEX_RE.match(name)
                if lm:
                    addr = int(lm.group(1), 16) - (BIAS if L_HEX_RE.match(name) else 0)
                continue
            if stripped.startswith(('db', '.byte', '.word', '.ascii')):
                continue          # data carries no control flow
            parts = stripped.split()
            mnem = parts[0]
            if addr is None:
                continue
            mnem_at[addr] = mnem
            if mnem == 'call':
                t = TARGET_RE.search(stripped)
                if t:
                    calls.add(int(t.group(1), 16) - BIAS)
            elif mnem in JUMPS:
                t = TARGET_RE.search(stripped)
                if t:
                    jumps.setdefault(addr, []).append(int(t.group(1), 16) - BIAS)
            elif mnem == 'ret':
                rets.add(addr)
    return calls, jumps, rets, mnem_at


def load_rows():
    rows = []
    with open(MAP) as f:
        next(f)
        for line in f:
            p = line.rstrip('\n').split('\t')
            if len(p) < 4:
                continue
            rows.append({'start': int(p[0], 16), 'end': int(p[1], 16),
                         'name': p[4] if len(p) > 4 else ''})
    rows.sort(key=lambda r: r['start'])
    return rows


def analyse(rows, calls, jumps, rets, mnem_at):
    """Attach the glue facts to each row and group runs."""
    for r in rows:
        s, e = r['start'], r['end']
        r['entry_call'] = s in calls
        r['n_calls'] = sum(1 for c in calls if s <= c <= e)
        r['n_rets'] = sum(1 for a in rets if s <= a <= e)
        ext = []
        internal = 0
        for frm, tos in jumps.items():
            for to in tos:
                if s <= to <= e:
                    if s <= frm <= e:
                        internal += 1
                    else:
                        ext.append((frm, to))
        r['inbound_external_jumps'] = ext
        r['internal_jumps'] = internal
        # the last branch inside the row, by address
        tail = None
        for a in sorted(x for x in jumps if s <= x <= e):
            tail = (a, jumps[a])
        r['tail'] = tail
        r['last_mnem'] = None
        for a in sorted(mnem_at):
            if s <= a <= e:
                r['last_mnem'] = mnem_at[a]
    return rows


def glue(a, b):
    """Is row b glued to row a? See the module docstring for the rule."""
    if b['start'] != a['end'] + 1:
        return False                       # not adjacent
    if b['n_calls']:
        return False                       # b has its own entry point
    for frm, to in b['inbound_external_jumps']:
        if not (a['start'] <= frm <= a['end']):
            return False                   # a third party branches into b
    if a['last_mnem'] == 'ret':
        return False
    if a['tail']:
        addr, tos = a['tail']
        if a['last_mnem'] in UNCOND and all(not (b['start'] <= t <= b['end']) for t in tos):
            return False                   # unconditional jump elsewhere: a real tail call
    return True


def find_runs(rows):
    runs, cur = [], [rows[0]]
    for prev, nxt in zip(rows, rows[1:]):
        if glue(prev, nxt):
            cur.append(nxt)
        else:
            if len(cur) > 1:
                runs.append(cur)
            cur = [nxt]
    if len(cur) > 1:
        runs.append(cur)
    out = []
    for run in runs:
        total_rets = sum(r['n_rets'] for r in run)
        last_rets = run[-1]['n_rets']
        if total_rets == 1 and last_rets == 1:
            grade = 'strong' if run[0]['entry_call'] else 'probable'
        else:
            grade = 'tail-chain'      # zero rets, or more than one: not a split claim
        out.append({'rows': run, 'rets': total_rets, 'grade': grade,
                    'entry': run[0]['entry_call']})
    return out


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument('--tsv', action='store_true')
    ap.add_argument('--selftest', action='store_true')
    ap.add_argument('--all', action='store_true', help='include weak candidates')
    a = ap.parse_args()

    calls, jumps, rets, mnem_at = parse_asm_dir()
    rows = load_rows()
    analyse(rows, calls, jumps, rets, mnem_at)
    runs = find_runs(rows)

    if a.selftest:
        return selftest(runs, rows)

    strong = [r for r in runs if r['grade'] == 'strong']
    probable = [r for r in runs if r['grade'] == 'probable']
    chains = [r for r in runs if r['grade'] == 'tail-chain']
    shown = strong + (probable if a.all else [])
    if a.tsv:
        print('start\tend\tn_fragments\trets\tentry_call\tgrade')
        for r in shown:
            print('%04X\t%04X\t%d\t%d\t%s\t%s' % (
                r['rows'][0]['start'], r['rows'][-1]['end'], len(r['rows']),
                r['rets'], 'yes' if r['entry'] else 'no', r['grade']))
    else:
        print('fragment-split candidates in %d map rows (%d asm files)'
              % (len(rows), len(os.listdir(ASMDIR))))
        print('  strong: %d   probable: %d   (tail-chains excluded: %d)'
              % (len(strong), len(probable), len(chains)))
        for r in shown:
            span = '%04X..%04X' % (r['rows'][0]['start'], r['rows'][-1]['end'])
            names = ', '.join(x['name'] or 'sub_%04x' % x['start'] for x in r['rows'])
            print('\n  [%s] %s  -- %d fragments, 1 ret'
                  % (r['grade'], span, len(r['rows'])))
            print('          %s' % names)
    return 0


def selftest(runs, rows):
    """Assert both directions. A detector that flags everything passes nothing."""
    def flagged(start):
        return any(r['rows'][0]['start'] <= start <= r['rows'][-1]['end'] for r in runs)

    def run_of(start):
        for r in runs:
            if r['rows'][0]['start'] <= start <= r['rows'][-1]['end']:
                return r
        return None

    must = {'51A5': ('51A5', '51A9'), '53B5': ('53B5', '53C5')}
    must_not = {'15E1 tavern_menu': 0x15E1, '1799 food_price': 0x1799,
                '2028 (merged)': 0x2028, '2052 (merged)': 0x2052,
                '20AB (merged)': 0x20AB}
    fail = 0
    for label, addrs in must.items():
        r = run_of(int(addrs[0], 16))
        ok = (r is not None and r['grade'] != 'tail-chain'
              and {('%04X' % x['start']) for x in r['rows']} >= set(addrs))
        print('POSITIVE %-18s expected %s in one candidate run -> %s'
              % (label, '+'.join(addrs), 'OK' if ok else 'MISS'))
        fail += 0 if ok else 1
    for label, start in must_not.items():
        r = run_of(start)
        ok = r is None or r['grade'] == 'tail-chain'
        detail = ''
        if not ok:
            detail = ' (candidate run %04X..%04X, %s)'.replace('%s', r['grade']) % (
                r['rows'][0]['start'], r['rows'][-1]['end'])
        print('NEGATIVE %-18s must not be a candidate -> %s%s'
              % (label, 'OK' if ok else 'FALSE POSITIVE', detail))
        fail += 0 if ok else 1
    print('SELFTEST: %s' % ('PASS' if fail == 0 else 'FAIL (%d)' % fail))
    return 0 if fail == 0 else 1


if __name__ == '__main__':
    sys.exit(main())
