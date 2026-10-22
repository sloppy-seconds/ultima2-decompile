#!/usr/bin/env python3
"""monster_hp_dispatch.py — extract the per-kind monster HP immediates and check them.

Why: monster HP is not a table. tools/hp_table_scan.py searched the executable for a
stored per-creature HP table across 13 encoding x indexing combinations and found
none, correctly. The values are immediates inside a chain of compares on the monster
type byte, in the asm/0D??_monster_hp_* family, each arm storing a type to
[DI+0x197] and an HP to [DI+0x177].

[DI+0x177] is proven to be HP by asm/2E3D_combat_attack_flow: it subtracts the damage
byte at [DS:20] from it and, when the subtraction borrows, zeroes HP, type and sprite
together. That is the load/store pattern this tool relies on.

The tool does two things:

1. prints every (type, HP) pair it finds, with the art the type folds to under >>2
2. cross-checks each pair against the third-party bestiary HP (docs/bestiary.md), and
   **exits non-zero on a disagreement** — so it doubles as a gate. If the binary and
   the community table ever diverge, this goes red rather than quietly printing both.

Control (`--self-test`): the checker is fed a perturbed expectation and must report a
mismatch. A comparison that cannot fail is not evidence.

Usage:
    python3 tools/monster_hp_dispatch.py
    python3 tools/monster_hp_dispatch.py --self-test
"""
import argparse
import os
import re
import sys

PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASM = os.path.join(PROJECT_ROOT, 'asm')

# art index -> (third-party name, third-party HP). Sourced from the Ultima Codex and
# Gamer Corner via docs/bestiary.md; these are THIRD-PARTY, and a mismatch here means
# the community table and the binary disagree, not that the binary is wrong.
WIKI = {
    0x0B: ('Sea serpent', 64), 0x0C: ('Orc', 16), 0x0D: ('Daemon', 64),
    0x0E: ('Devil', 192), 0x0F: ('Balron', 255), 0x12: ('Frigate', 160),
    0x18: ('Guard', 255), 0x3C: ('Fighter', 128), 0x3D: ('Cleric', 10),
    0x3E: ('Wizard', 224), 0x3F: ('Thief', 32),
}

RE_IMM = re.compile(r'mov\s+\$0x([0-9a-fA-F]{1,2}),%al\b')
RE_TYPE = re.compile(r'mov\s+%al,0x197\(%di\)')
RE_HP = re.compile(r'mov\s+%al,0x177\(%di\)')
RE_LBL = re.compile(r'^([A-Za-z_]\w*):')


def scan_file(path):
    """Pair each store into [DI+0x197] with the next store into [DI+0x177]."""
    out, al, typ = [], None, None
    for ln in open(path, encoding='utf-8', errors='replace'):
        ln = ln.rstrip()
        if RE_LBL.match(ln):
            continue
        m = RE_IMM.search(ln)
        if m:
            al = int(m.group(1), 16)
            continue
        if RE_TYPE.search(ln):
            typ = al
        elif RE_HP.search(ln):
            if al is not None:
                out.append((typ, al))
            typ = None
    return out


def collect(asm_dir=ASM):
    rows = []
    for fn in sorted(os.listdir(asm_dir)):
        if not fn.endswith('.asm'):
            continue
        for typ, hp in scan_file(os.path.join(asm_dir, fn)):
            rows.append((typ, hp, fn))
    seen, uniq = set(), []
    for r in rows:
        if (r[0], r[1]) in seen or r[0] is None or r[0] == 0:
            continue
        seen.add((r[0], r[1]))
        uniq.append(r)
    return sorted(uniq, key=lambda r: r[1])


def check(rows, wiki):
    """Return (matches, mismatches, unchecked)."""
    ok, bad, un = [], [], []
    for typ, hp, fn in rows:
        art = typ >> 2
        if art in wiki:
            name, want = wiki[art]
            (ok if want == hp else bad).append((typ, hp, art, name, want, fn))
        else:
            un.append((typ, hp, art, fn))
    return ok, bad, un


def self_test():
    rows = collect()
    if not rows:
        return ['no (type, HP) pairs extracted — the asm/ family was renamed or '
                'the store pattern changed, so this tool is now blind']
    ok, bad, _ = check(rows, WIKI)
    if not ok:
        return ['extracted %d pairs but none cross-check against the third-party '
                'table — either the wiki changed or the decode is wrong' % len(rows)]
    # perturb one expectation: the checker must notice a wrong HP value
    lie = dict((a, (n, v + 1)) for a, (n, v) in WIKI.items())
    _, bad2, _ = check(rows, lie)
    if len(bad2) != len(ok):
        return ['control FAILED: perturbing every expected HP by +1 produced %d '
                'mismatches instead of %d — the comparison cannot fail'
                % (len(bad2), len(ok))]
    return []


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument('--self-test', action='store_true')
    args = ap.parse_args()

    if args.self_test:
        fails = self_test()
        if fails:
            for f in fails:
                print(f)
            print('\nSELF-TEST FAILED — do not trust this extractor')
            sys.exit(1)
        print('self-test passed: pairs extracted, cross-check non-empty, and a '
              '+1 perturbation of every expectation was detected')
        return

    rows = collect()
    print('%-6s %-5s %-5s %-52s %s' % ('type', 'HP', 'art', 'file', 'third-party'))
    for typ, hp, fn in rows:
        art = typ >> 2
        name, want = WIKI.get(art, (None, None))
        note = ''
        if want is not None:
            note = '%-14s %d %s' % (name, want,
                                    'match' if want == hp else 'DISAGREE got %d' % hp)
        print('0x%02X  %-5d 0x%02X  %-52s %s' % (typ, hp, art, fn, note))

    ok, bad, un = check(rows, WIKI)
    print('\n%d arms extracted; %d cross-check against the third-party table, '
          '%d disagree, %d unchecked (no third-party HP for that art)'
          % (len(rows), len(ok), len(bad), len(un)))
    print('HP field: [DI+0x177] (monster record), proven by asm/2E3D_combat_attack_flow')
    if bad:
        print('\nDISAGREEMENTS — binary vs community table:')
        for typ, hp, art, name, want, fn in bad:
            print('  type 0x%02X art 0x%02X %s: binary=%d wiki=%d (%s)'
                  % (typ, art, name, hp, want, fn))
        sys.exit(1)
    print('\nno disagreements. Note this proves the VALUES, not the NAMES: the names '
          'are third-party and enter only through the bitmap join in docs/bestiary.md.')


if __name__ == '__main__':
    main()
