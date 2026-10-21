#!/usr/bin/env python3
"""Patch a Ultima II `player` save file.

Why this exists: writing DS:00/01 in the live emulator does NOT teleport the
player. The write lands and reads back, but movement then stops working
entirely - DS:00/01 is a mirror the game updates, not the value it drives
movement from. The reliable way to place the character is to edit the save and
let the game load it.

Measured save layout (384 bytes, from tmp/.../player for the TEST character):

    0x00..0x03  name, ASCII, NUL padded
    0x10        0x4D ('M')
    0x15        0x50
    0x24        x on map      <- mirrors DS:00 once loaded
    0x25        y on map      <- mirrors DS:01 once loaded
    0x100       0x1A

Sector is NOT in the save; the game tracks it separately, so this tool can only
place you within the sector you will land in.

Usage:
    python3 tools/u2_edit.py show player
    python3 tools/u2_edit.py setpos player 19 39
    python3 tools/u2_edit.py setpos player 19 39 -o /var/tmp/tp/player
"""
import argparse
import os
import shutil
import sys

OFF_NAME = 0x00
OFF_X = 0x24
OFF_Y = 0x25
SIZE = 384


def load(path):
    data = bytearray(open(path, 'rb').read())
    if len(data) != SIZE:
        sys.exit('%s: expected %d bytes, got %d' % (path, SIZE, len(data)))
    return data


def save(data, path):
    with open(path, 'wb') as f:
        f.write(bytes(data))


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('cmd', choices=['show', 'setpos'])
    ap.add_argument('file')
    ap.add_argument('args', nargs='*')
    ap.add_argument('-o', '--out', help='write here instead of in place')
    a = ap.parse_args()

    d = load(a.file)
    name = bytes(d[OFF_NAME:OFF_NAME + 4]).rstrip(b'\x00').decode('latin-1')

    if a.cmd == 'show':
        print('name   %s' % name)
        print('pos    (%d, %d)   at 0x%02X/0x%02X' % (d[OFF_X], d[OFF_Y], OFF_X, OFF_Y))
        print('0x100  0x%02X' % d[0x100])
        return

    if len(a.args) != 2:
        sys.exit('setpos needs X and Y')
    x, y = int(a.args[0]), int(a.args[1])
    if not (0 <= x < 64 and 0 <= y < 64):
        sys.exit('position %d,%d outside the 64x64 map' % (x, y))

    out = a.out or a.file
    if a.out:
        os.makedirs(os.path.dirname(os.path.abspath(out)), exist_ok=True)
        shutil.copyfile(a.file, out)
        d = load(out)

    old = (d[OFF_X], d[OFF_Y])
    d[OFF_X], d[OFF_Y] = x, y
    save(d, out)

    check = load(out)
    if (check[OFF_X], check[OFF_Y]) != (x, y):
        sys.exit('write did not land: read back (%d,%d)' % (check[OFF_X], check[OFF_Y]))
    print('%s: %s pos (%d,%d) -> (%d,%d)' % (out, name, old[0], old[1], x, y))


if __name__ == '__main__':
    main()
