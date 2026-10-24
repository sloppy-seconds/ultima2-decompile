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

THE ONE EXCEPTION: a marked body correction
-------------------------------------------
Sometimes the body is provably WRONG, not merely mis-filed. asm/353A forced-kept one byte
of a four-byte instruction and asm/353D then decoded the leftover bytes as `push %ds` and
`dec %cx`: mnemonics that are not the code. `tools/forced_keep_audit.py` finds at least 63
such sites. Freezing those bodies forever protects a known falsehood, which is not what a
proof is for.

So a body may change IF AND ONLY IF the file carries a marker line:

    # body corrected: YYYY-MM-DD -- evidence: <what proved the old decode wrong>

and the marker must name its evidence. The marker grants permission to edit, it does not
grant permission to be wrong: **`tools/assemble_clean.sh` remains the authority.** A
corrected body that changes any byte fails there, so a marker cannot smuggle in a semantic
change -- if it still assembles to the same bytes it is by construction a valid decode of
them. The two gates are deliberately different: this one polices authorship, that one
polices truth.

Merging and splitting still need no marker, because they preserve the canonical stream.
Removing a file whose body lines vanish is still a failure even with a marker: the content
has to go somewhere.

Exit 0 = body content conserved, or changed only in marked files. Exit 1 = changed in an
unmarked file, or content removed.
"""
import re
import subprocess
import sys

START_RE = re.compile(r'^([0-9A-Fa-f]{4})_')
MARKER_RE = re.compile(r'^#\s*body corrected:\s*(.+)$', re.I)
EVIDENCE_RE = re.compile(r'evidence\s*:', re.I)


def marker_in(text):
    """Return the marker's text if the file carries a well-formed one, else None."""
    for ln in text.splitlines():
        m = MARKER_RE.match(ln)
        if m:
            body = m.group(1).strip()
            if not EVIDENCE_RE.search(body):
                return 'MALFORMED (must include "evidence:")'
            return body
    return None


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


def raw_from_git(ref):
    """{filename: full text} for asm/ at a git ref, so markers can be read."""
    listing = subprocess.run(
        ['git', 'ls-tree', '-r', '--name-only', ref, '--', 'asm/'],
        capture_output=True, text=True, check=True).stdout.split()
    out = {}
    for path in listing:
        if path.endswith('.asm'):
            out[path] = subprocess.run(['git', 'show', f'{ref}:{path}'],
                                       capture_output=True, text=True,
                                       check=True).stdout
    return out


def raw_from_worktree():
    import glob
    out = {}
    for path in sorted(glob.glob('asm/*.asm')):
        out[path] = open(path, errors='replace').read()
    return out


def main():
    head = stream_from_git('HEAD')
    work = stream_from_worktree()
    a, b = canonical(head), canonical(work)
    if a == b:
        print('asm/ body content conserved (%d lines, %d -> %d files)'
              % (len(b), len(head), len(work)))
        return 0

    # The stream changed. That is legal only inside files that carry a correction marker.
    head_raw, work_raw = raw_from_git('HEAD'), raw_from_worktree()
    offenders, permitted = [], []
    for path in sorted(set(head_raw) | set(work_raw)):
        old, new = head_raw.get(path), work_raw.get(path)
        if old is None:            # brand-new file: its body is new content
            mk = marker_in(new) if new else None
            (permitted if mk else offenders).append((path, mk or 'new file, no marker'))
        elif new is None:          # removed file: its body went somewhere or vanished
            offenders.append((path, 'file removed'))
        elif head_raw[path] != work_raw[path] and body_lines(old) != body_lines(new):
            mk = marker_in(new)
            (permitted if mk else offenders).append(
                (path, mk or 'body changed, no marker'))
    if offenders:
        print('asm/ BODY CONTENT CHANGED (%d lines at HEAD -> %d now)' % (len(a), len(b)))
        for i, (x, y) in enumerate(zip(a, b)):
            if x != y:
                print('  first difference at body line %d:' % i)
                print('    HEAD: %r' % x)
                print('    now : %r' % y)
                break
        else:
            print('  prefix identical; length differs (content added or removed)')
        print('\n  %d file(s) changed body WITHOUT a valid marker:' % len(offenders))
        for path, why in offenders:
            print('    %s  (%s)' % (path.split('/')[-1], why))
        print('\n  To correct a provably-wrong decode, add to that file:\n'
              '    # body corrected: YYYY-MM-DD -- evidence: <what proved it>\n'
              '  then run tools/assemble_clean.sh: a correction that changes any byte\n'
              '  must still fail there, and that failure is the real gate.')
        return 1
    print('asm/ body content CHANGED in %d marked file(s) -- permitted:' % len(permitted))
    for path, mk in permitted:
        print('  %s\n      marker: %s' % (path.split('/')[-1], mk))
    print('  REMINDER: this gate only checks authorship. Run tools/assemble_clean.sh;\n'
          '  a marked correction that changes any byte must fail there.')
    return 0


if __name__ == '__main__':
    sys.exit(main())
