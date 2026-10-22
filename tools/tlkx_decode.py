#!/usr/bin/env python3
"""Decode the shipped tlkxNN street-NPC dialogue files.

Each file is high-bit-set ASCII (the Apple II convention): every text byte has
0x80 set, and 0x00 separates records. Masking 0x80 yields readable lines of the
form `<NPC> <VERB>: <LINE>`. This was recorded as an open extractor requirement
in docs/phase4-state.md § Deferred decisions; this tool is the reference decode.

Read-only. Writes nothing; output goes to stdout.

Usage: python3 tools/tlkx_decode.py [original/tlkxNN ...]
"""
import glob
import os
import sys


def records(path):
    raw = open(path, 'rb').read()
    out, cur = [], []
    for b in raw:
        if b == 0x00:
            if cur:
                out.append(bytes(cur))
                cur = []
            continue
        if b & 0x80:
            cur.append(b & 0x7F)
        else:
            # Non-text byte inside a record: the tail marker (0x1A at 0x100 in
            # the player file shows the same shape) or padding. End the record.
            if cur:
                out.append(bytes(cur))
                cur = []
    if cur:
        out.append(bytes(cur))
    lines = []
    for r in out:
        s = r.decode('latin1').strip()
        if len(s) >= 3:
            lines.append(s)
    return lines


def main(argv):
    paths = argv[1:] or sorted(glob.glob('original/tlkx*'))
    for p in paths:
        recs = records(p)
        print('== %s  (%d records) ==' % (os.path.basename(p), len(recs)))
        for s in recs:
            print('   ' + s)
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv))
