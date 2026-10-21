#!/usr/bin/env python3
"""Ultima II `player` save editor.

The save record is the 256 bytes the game keeps in its DS working segment at
DS:0x36..0x135 (see engine/src/core/state.h, which names the range "the 256
bytes the game saves"). Verified 2026-10-21 by loading a character and comparing
all 256 bytes of the live DS block against the file: 254/256 identical, the two
exceptions being DS:74/75, live scratch that is not persisted.

    save_offset = DS_offset - 0x36

Why edit the save instead of poking memory: writing DS:00/01 in a live emulator
does NOT teleport the player. The write lands and reads back, but movement then
stops working entirely - DS:00/01 is a mirror, not the source. Editing the save
and reloading is the reliable path, and it is the only way to change sector.

Sector is stored as two DECIMAL DIGITS (DS:49/4A are patched into the filename
MAPXFF by asm/2290), so sector 20 is the pair 2,0 - not the integer 20. A
numeric read of that pair yields 512, which is a trap worth knowing.

Fields, all proven by live correlation or by cited asm in state.h:

    save  DS    field
    0x00  36    name (16 bytes, NUL padded)
    0x10  46    sex      'M' / 'F'
    0x11  47    class    0 fighter, 1 mage, 2 paladin, 3 thief (after sub 0x31)
    0x12  48    race     0 human, 1 elf, 2 dwarf, 3 hobbit
    0x13  49    sector first digit
    0x14  4A    sector second digit (also site kind outside a sector read:
                 0 overworld, 1 village, 2 town, 4 tower)
    0x15  4B    strength
    0x16  4C    agility
    0x17  4D    stamina
    0x18  4E    charisma
    0x19  4F    wisdom
    0x1A  50    intelligence
    0x1B  51    hit points
    0x1D  53    food (3-byte BCD, hundreds first: 53,54,55)
    0x20  56    experience (2-byte BCD: 56,57)
    0x22  58    gold (2-byte BCD, hundreds first: 58,59)
    0x24  5A    entry x   <- the game copies this to DS:00 on load
    0x25  5B    entry y   <- the game copies this to DS:01 on load
    0x2D  63    readied spell

NOT YET LOCATED: the inventory and equipment slots. They live somewhere in
DS:64..135, which reads as all zeros for a character carrying nothing, so the
slots cannot be identified until a save that actually holds items is compared.
`items` is therefore refused rather than guessed.

Usage:
    python3 tools/u2_edit.py show player
    python3 tools/u2_edit.py set player hp 999
    python3 tools/u2_edit.py set player sector 71
    python3 tools/u2_edit.py set player pos 20 20
    python3 tools/u2_edit.py maxout player
    python3 tools/u2_edit.py set player str 40 -o /var/tmp/tp/player
"""
import argparse
import os
import shutil
import sys

SIZE = 384
BASE = 0x36          # save_offset = DS_offset - BASE

# name -> (DS offset, width, max, kind)
FIELDS = {
    'name':   (0x36, 16, None, 'text'),
    'sex':    (0x46, 1, None, 'char'),
    'class':  (0x47, 1, 3, 'int'),
    'race':   (0x48, 1, 3, 'int'),
    'sector': (0x49, 2, 99, 'sector'),
    'str':    (0x4B, 1, 255, 'int'),
    'agi':    (0x4C, 1, 255, 'int'),
    'sta':    (0x4D, 1, 255, 'int'),
    'cha':    (0x4E, 1, 255, 'int'),
    'wis':    (0x4F, 1, 255, 'int'),
    'int':    (0x50, 1, 255, 'int'),
    'hp':     (0x51, 2, 9999, 'bcd'),    # 4-digit BCD across 0x51,0x52: hp=4,
                                          # 0x52=0 displays as H.P.=0400. A raw
                                          # byte write of 255 gives 0xFF, whose
                                          # nibbles are not decimal digits, and
                                          # the game prints "??" for those.
    'food':   (0x53, 3, 999999, 'bcd'),   # 6-digit counter; the status band
                                          # prints only the top 4 digits, so
                                          # 40000 displays as FOOD=0400
    'exp':    (0x56, 2, 9999, 'bcd'),
    'gold':   (0x58, 2, 9999, 'bcd'),
    'entry_x': (0x5A, 1, 63, 'int'),
    'entry_y': (0x5B, 1, 63, 'int'),
    'spell':  (0x63, 1, 255, 'int'),
}
CLASS_NAMES = {0: 'fighter', 1: 'mage', 2: 'paladin', 3: 'thief'}
RACE_NAMES = {0: 'human', 1: 'elf', 2: 'dwarf', 3: 'hobbit'}

# A durable test character. Stats are what the creation roller produced for the
# TEST character (str 80 was observed live); 40 is a conservative "strong" value
# rather than a proven cap - the real maximum is not established by the asm.
MAXOUT = {'str': 40, 'agi': 40, 'sta': 40, 'cha': 40, 'wis': 40, 'int': 40,
          'hp': 9999, 'food': 999999, 'gold': 9999, 'exp': 9999}


def bcd_decode(raw):
    """BCD bytes hold decimal digits in their nibbles: 0x04 0x00 means "0400".
    Render each byte as two hex characters to recover the digit string, then
    read that string as DECIMAL. Parsing it as hex is the classic mistake and
    reports gold 400 as 1024."""
    return int(''.join('%02X' % b for b in raw), 10)


def bcd_encode(value, width):
    """Inverse: split the decimal digits into pairs and pack each pair into one
    byte's nibbles, so 400 -> 0x04 0x00 and 9999 -> 0x99 0x99."""
    digits = str(value)
    if len(digits) > width * 2:
        raise ValueError('%d does not fit in %d BCD bytes' % (value, width))
    digits = digits.zfill(width * 2)
    return [int(digits[i:i + 2], 16) for i in range(0, len(digits), 2)]


def load(path):
    d = bytearray(open(path, 'rb').read())
    if len(d) != SIZE:
        sys.exit('%s: expected %d bytes, got %d' % (path, SIZE, len(d)))
    return d


def get(d, name):
    off, width, _, kind = FIELDS[name]
    raw = d[off - BASE: off - BASE + width]
    if kind == 'text':
        return bytes(raw).rstrip(b'\x00').decode('latin-1')
    if kind == 'char':
        return chr(raw[0])
    if kind == 'sector':
        return raw[0] * 10 + raw[1]
    if kind == 'bcd':
        return bcd_decode(raw)
    return raw[0]


def put(d, name, value):
    off, width, mx, kind = FIELDS[name]
    i = off - BASE
    if kind == 'text':
        v = str(value).encode('latin-1')[:16]
        d[i:i + 16] = v + bytes(16 - len(v))
        return
    if kind == 'char':
        d[i] = ord(str(value)[0].upper())
        return
    n = int(value)
    if mx is not None and not (0 <= n <= mx):
        raise ValueError('%s=%d out of range 0..%d' % (name, n, mx))
    if kind == 'sector':
        d[i], d[i + 1] = n // 10, n % 10
    elif kind == 'bcd':
        d[i:i + width] = bytes(bcd_encode(n, width))
    else:
        d[i] = n


def show(d):
    print('name    %s' % get(d, 'name'))
    print('sex     %s' % get(d, 'sex'))
    print('class   %d (%s)' % (get(d, 'class'), CLASS_NAMES.get(get(d, 'class'), '?')))
    print('race    %d (%s)' % (get(d, 'race'), RACE_NAMES.get(get(d, 'race'), '?')))
    print('sector  %d' % get(d, 'sector'))
    for f in ('str', 'agi', 'sta', 'cha', 'wis', 'int'):
        print('%-7s %d' % (f, get(d, f)))
    print('hp      %d' % get(d, 'hp'))
    print('food    %d' % get(d, 'food'))
    print('gold    %d' % get(d, 'gold'))
    print('exp     %d' % get(d, 'exp'))
    print('entry   (%d, %d)' % (get(d, 'entry_x'), get(d, 'entry_y')))
    print('spell   %d' % get(d, 'spell'))
    print('\nitems/equipment: NOT LOCATED (see module docstring)')


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('cmd', choices=['show', 'set', 'setpos', 'maxout'])
    ap.add_argument('file')
    ap.add_argument('args', nargs='*')
    ap.add_argument('-o', '--out')
    a = ap.parse_args()

    low = a.file.lower()
    if '/references/' in low or ('/original/' in low and not a.out):
        sys.exit('refusing to modify original/ or references/ in place; use -o')

    d = load(a.file)
    out = a.out or a.file
    if a.out:
        os.makedirs(os.path.dirname(os.path.abspath(out)), exist_ok=True)
        shutil.copyfile(a.file, out)
        d = load(out)

    if a.cmd == 'show':
        show(d)
        return
    if a.cmd == 'maxout':
        for k, v in MAXOUT.items():
            put(d, k, v)
        print('maxout applied: %s' % ', '.join('%s=%s' % kv for kv in MAXOUT.items()))
    elif a.cmd == 'setpos':
        if len(a.args) != 2:
            sys.exit('setpos needs X and Y')
        put(d, 'entry_x', int(a.args[0]))
        put(d, 'entry_y', int(a.args[1]))
        print('entry -> (%s, %s)' % tuple(a.args))
    elif a.cmd == 'set':
        if len(a.args) != 2:
            sys.exit('set needs FIELD VALUE')
        f, v = a.args
        if f == 'items':
            sys.exit('item slots are not located yet; refusing to guess')
        if f not in FIELDS:
            sys.exit('unknown field %r; known: %s' % (f, ', '.join(sorted(FIELDS))))
        put(d, f, v)
        print('%s -> %s' % (f, v))
    else:
        sys.exit('unknown command')

    with open(out, 'wb') as f:
        f.write(bytes(d))
    chk = load(out)
    if a.cmd == 'set':
        got = get(chk, a.args[0])
        if str(got) != str(int(a.args[1])) and a.args[0] not in ('name', 'sex'):
            sys.exit('write did not land: read back %r' % got)
    print('wrote %s' % out)


if __name__ == '__main__':
    main()
