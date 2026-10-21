#!/usr/bin/env python3
"""patch_arrows.py — make a run copy of the game accept real arrow keys.

WHY THIS EXISTS
The game translates an extended scancode into a direction character only when the
byte DOS reports as the "character" is zero. The gate is at runtime 0x4F85
(file 0x5185), confirmed against original/ultimaii.exe on 2026-10-21:

    5185  3C 00     cmp al,$0x00
    5187  75 48     jne  $0x4FD1     ; AL != 0 -> skip translation, return ah=0xFF
    ...
    51BB  mov bx,$0x6
    51BE  cmp ah,[bx+0x4f09]         ; the table matches on AH only, never AL
    51C3  je  translate
    51CC  mov al,[bx+0x4f0a]

The scancode table at CS:0x4F09 (file 0x5109) holds exactly four pairs:
48->0E  50->19  4D->05  4B->17, which matches the direction codes live captures
read at DS:26E..271 = 0E 19 05 17.

Spice86 is believed to deliver a real arrow as AX = 0x48E0, i.e. the extended
prefix 0xE0 in AL where DOS would put 0x00. That claim came from a sibling
project and is a HYPOTHESIS here, not a measurement; tools/spice86_keys.py tests
it before relying on it.

THE PATCH
The table lookup keys on AH alone, so the AL gate is the only thing in the way.
Replacing the two-byte conditional jump with a no-op removes the check and lets
both AL=0x00 and AL=0xE0 reach the table.

Side effect, accepted deliberately: with NumLock ON, numpad 8/4/6/2 arrive as
AL='8' etc. with AH in {48,4B,4D,50}, and would then be read as arrows instead of
digits. The scancodes involved belong to no letter key, so nothing else is
affected. spice86_keys.py forces NumLock off at startup to remove the case.
A tighter test (accept exactly 0x00 and 0xE0) does not fit in the 4-byte slot and
would require relocating code; that trade was considered and rejected.

THIS NEVER TOUCHES original/. It operates on a run copy under tmp/ only, and it
refuses if the expected bytes are not present rather than patching blind.

Usage:
    python3 tools/patch_arrows.py tmp/<run>/ultimaii.exe
    python3 tools/patch_arrows.py --check tmp/<run>/ultimaii.exe
"""
import argparse
import os
import sys

# File offsets in the MZ image. runtime = file - 0x200 for this binary.
GATE_OFF = 0x5185
EXPECTED = bytes([0x3C, 0x00, 0x75, 0x48])   # cmp al,0x00 ; jne +0x48
PATCHED = bytes([0x3C, 0x00, 0x90, 0x90])    # cmp al,0x00 ; nop ; nop
TABLE_OFF = 0x5109
TABLE_EXPECT = bytes([0x48, 0x0E, 0x50, 0x19, 0x4D, 0x05, 0x4B, 0x17])

MIN_SIZE = 0x5200


def die(msg):
    print('FATAL: %s' % msg, file=sys.stderr)
    sys.exit(1)


def guard(path):
    """Refuse to touch anything that is not a scratch run copy."""
    real = os.path.realpath(path)
    root = os.path.realpath(os.path.join(os.path.dirname(__file__), '..'))
    if not real.startswith(root + os.sep):
        die('%s is outside the project root' % path)
    if 'tmp' not in real.split(os.sep):
        die('%s is not under tmp/ — refusing to patch anything but a run copy. '
            'original/ and references/ are never patched.' % path)
    if not os.path.exists(real):
        die('%s does not exist' % path)
    return real


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('exe')
    ap.add_argument('--check', action='store_true',
                    help='report state without writing')
    args = ap.parse_args()

    path = guard(args.exe)
    data = bytearray(open(path, 'rb').read())
    if len(data) < MIN_SIZE:
        die('%s is %d bytes, too small to contain the key handler' % (path, len(data)))

    # Verify the table first: if this is not the binary we analysed, stop.
    got_table = bytes(data[TABLE_OFF:TABLE_OFF + 8])
    if got_table != TABLE_EXPECT:
        die('scancode table at file 0x5109 is %s, expected %s — this is not the '
            'binary the patch was derived from, refusing'
            % (got_table.hex(), TABLE_EXPECT.hex()))

    got = bytes(data[GATE_OFF:GATE_OFF + 4])
    if got == PATCHED:
        print('already patched: file 0x%04X = %s' % (GATE_OFF, got.hex()))
        return 0
    if got != EXPECTED:
        die('gate at file 0x%04X is %s, expected %s — refusing to patch blind'
            % (GATE_OFF, got.hex(), EXPECTED.hex()))

    if args.check:
        print('unpatched: file 0x%04X = %s (gate active, real arrows will be ignored)'
              % (GATE_OFF, got.hex()))
        return 0

    data[GATE_OFF:GATE_OFF + 4] = PATCHED
    with open(path, 'wb') as fh:
        fh.write(bytes(data))

    # Read back and prove it landed. A silent no-op is the failure mode to avoid.
    back = open(path, 'rb').read()[GATE_OFF:GATE_OFF + 4]
    if back != PATCHED:
        die('write did not land: read back %s' % back.hex())
    print('patched: file 0x%04X %s -> %s  (verified by read-back)'
          % (GATE_OFF, EXPECTED.hex(), back.hex()))
    return 0


if __name__ == '__main__':
    sys.exit(main())
