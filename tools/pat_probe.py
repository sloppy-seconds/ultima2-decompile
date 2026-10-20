#!/usr/bin/env python3
"""pat_probe.py — is our original/ copy patched, and if so how far?

The Exodus upgrade ships .pat files plus a u2up.ini that names the release lineage:

    none        Ultima Trilogy I-II-III (1989)
    u2-u16.pat  Ultima I-VI Series (1991)
    u2-uc.pat   Micro Dragon's Speed Fix / Ultima Collection (1997)
    u2-map.pat  Moonstone Dragon's Map Patch (1997)
    u2-gog.pat  GOG.com (2007)

AGENTS.md carries this as an accepted caveat: the pack "appears to already have
community patches applied". This turns that caveat into a measurement.

Record layout, read from the bytes (this is a READING AID for a third-party format,
not a reimplementation of the patcher -- nothing here writes anything):

    PZ1\\0  u32 total_size  <file records>
    FZ1\\0  <44-byte name>  <44-byte name?> ...
    DZ1\\0  u32 offset  u32 size  u32 flags  <size bytes>

A DZ1 whose bytes are already present in our file is "applied"; one whose bytes are
absent is "not applied". The verdict is the ratio, per patch file, per target file.

Read-only. Never writes to the .exe or to a .pat.
"""
import argparse
import os
import struct
import sys

ap = argparse.ArgumentParser()
ap.add_argument('--exe', default='original/ultimaii.exe')
ap.add_argument('--pats', default='references/u2upgrade')
ap.add_argument('--verbose', action='store_true')
args = ap.parse_args()

target = os.path.basename(args.exe)
data = open(args.exe, 'rb').read()
print('our %s: %d bytes (0x%x)\n' % (target, len(data), len(data)))

for name in sorted(os.listdir(args.pats)):
    if not name.endswith('.pat'):
        continue
    blob = open(os.path.join(args.pats, name), 'rb').read()
    if blob[:4] != b'PZ1\x00':
        print('%-14s not a PZ1 container (%s)' % (name, blob[:4]))
        continue
    total = struct.unpack('<I', blob[4:8])[0]

    # Walk records. FZ1 introduces a target file; DZ1 is a byte run inside it.
    i, cur, runs = 8, None, []
    while i + 4 <= len(blob):
        magic = blob[i:i + 4]
        if magic == b'FZ1\x00':
            nm = blob[i + 4:i + 4 + 44].split(b'\0')[0].decode('latin1')
            cur = nm
            i += 4 + 44
            # a second 44-byte name field follows in the samples
            if blob[i + 40:i + 44] == b'\0' * 4 and blob[i:i + 4] != b'DZ1\x00':
                i += 44
            if blob[i + 4:i + 8] == b'\0' * 4:
                i += 4
        elif magic == b'DZ1\x00':
            off, size, flags = struct.unpack('<III', blob[i + 4:i + 16])
            payload = blob[i + 16:i + 16 + size]
            runs.append((cur, off, size, flags, payload))
            i += 16 + size
        else:
            i += 1

    mine = [r for r in runs if r[0].upper() == target.upper()]
    others = sorted({r[0] for r in runs if r[0].upper() != target.upper()})
    print('%-14s declared=%-7s runs=%-4d for %s' %
          (name, hex(total), len(mine), target))
    if not mine:
        if others:
            print('               (touches %d other files: %s)' %
                  (len(others), ', '.join(others[:6])))
        continue
    applied = sum(1 for _, off, size, _, p in mine
                  if data[off:off + size] == p)
    inside = sum(1 for _, off, size, _, p in mine if off + size <= len(data))
    print('               in-range=%d  bytes-already-present=%d/%d  (%.1f%%)' %
          (inside, applied, len(mine), 100.0 * applied / len(mine)))
    if args.verbose:
        for f, off, size, flags, p in mine[:8]:
            state = 'APPLIED' if data[off:off + size] == p else 'absent '
            print('                 %s off=%#x size=%#x flags=%#x' %
                  (state, off, size, flags))
