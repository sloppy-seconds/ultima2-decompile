#!/usr/bin/env python3
"""asm_body_guard.py — the asm/ invariant CP0 actually needs.

Why this exists instead of the older per-file md5 check
------------------------------------------------------
The previous guard compared, file by file, the md5 of each changed file's
non-comment lines against HEAD, and treated ANY deletion as a failure. That was
right while the only permitted asm/ edit was a rename. It became wrong the moment
function *boundaries* were allowed to move: merging seven fragments into one
routine deletes six files and grows a seventh, and every one of those six
deletions is the guard reporting success as vandalism.

What is genuinely invariant is not which file a line lives in. It is that the
**assemblable content of the whole tree** is unchanged: no instruction line added,
removed, reordered or edited. Renaming, merging and splitting are all legitimate
maintenance acts on that content; editing it is not.

The check
---------
Build a canonical stream: for every `asm/*.asm`, sorted by the 4-hex start address
in its filename, concatenate the file's non-comment lines. Because the fragments
tile their address ranges contiguously and in order, sorting by start address makes
the stream independent of where the file boundaries sit. Merging and splitting
preserve it exactly. Any body edit, insertion, deletion or reorder breaks it.

Compared against the same stream built from `HEAD`.

Comment lines (leading '#') are excluded, so headers, evidence notes and
provenance may be rewritten freely -- which is what AGENTS.md § 3 requires in the
same commit that renames a file.

Exit 0 = body content conserved. Exit 1 = changed, with a diff summary.
"""
import re
import subprocess
import sys

START_RE = re.compile(r'^([0-9A-Fa-f]{4})_')


def body_lines(text):
    """Non-comment, non-blank-only lines, exactly as the assembler sees them."""
    return [ln for ln in text.splitlines() if not ln.lstrip().startswith('#')]


def stream_from_git(ref):
    """{filename: body lines} for asm/ at a git ref."""
    listing = subprocess.run(
        ['git', 'ls-tree', '-r', '--name-only', ref, '--', 'asm/'],
        capture_output=True, text=True, check=True).stdout.split()
    out = {}
    for path in listing:
        if not path.endswith('.asm'):
            continue
        txt = subprocess.run(['git', 'show', f'{ref}:{path}'],
                             capture_output=True, text=True, check=True).stdout
        out[path] = body_lines(txt)
    return out


def stream_from_worktree():
    import glob
    import os
    out = {}
    for path in sorted(glob.glob('asm/*.asm')):
        out[path] = body_lines(open(path, errors='replace').read())
    return out


def canonical(files):
    """One flat list of body lines, ordered by each file's declared start address."""
    def key(item):
        path, _ = item
        base = path.split('/')[-1]
        m = START_RE.match(base)
        # files without a 4-hex prefix sort last, by name, deterministically
        return (0, int(m.group(1), 16), base) if m else (1, 0, base)
    flat = []
    for path, lines in sorted(files.items(), key=key):
        flat.extend(lines)
    return flat


def main():
    head = stream_from_git('HEAD')
    work = stream_from_worktree()
    a, b = canonical(head), canonical(work)
    if a == b:
        print('asm/ body content conserved (%d lines, %d -> %d files)'
              % (len(b), len(head), len(work)))
        return 0
    print('asm/ BODY CONTENT CHANGED (%d lines at HEAD -> %d now)' % (len(a), len(b)))
    # point at the first divergence, which is far more useful than a count
    for i, (x, y) in enumerate(zip(a, b)):
        if x != y:
            print('  first difference at body line %d:' % i)
            print('    HEAD: %r' % x)
            print('    now : %r' % y)
            break
    else:
        print('  prefix identical; length differs (content added or removed)')
    added = set(b) - set(a)
    removed = set(a) - set(b)
    if added:
        print('  %d body line(s) present now but not at HEAD' % len(added))
    if removed:
        print('  %d body line(s) at HEAD now missing' % len(removed))
    return 1


if __name__ == '__main__':
    sys.exit(main())
