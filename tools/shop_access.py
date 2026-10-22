#!/usr/bin/env python3
"""shop_access.py — which sectors actually place a transacting NPC beside a shop sign?

commerce.md § 5 established that `T` does nothing unless an NPC stands adjacent to the
shop tile, and that the first shop capture failed because sector 03 has no merchant
beside a letter tile. That is a data question, so this answers it for every sector at
once: for each shop sign of 3+ letters, is there a street-transacting NPC standing on
it or in the four orthogonal cells?

Read-only: original/mapxNN + original/monxNN. Proven output: sector 32 ARMOURY at
(35,4) with the Merchant at (38,3) is the configuration that finally opened a shop on
2026-10-23 (captures/spice86/armour-buy).
"""
import glob
import os

LETTER = {}
for a in range(0x20, 0x3A):
    if a == 0x30:
        continue
    LETTER[a << 2] = chr(ord('A') + (a - 0x20))

# monx type byte -> name (docs/bestiary.md); the street-transacting kinds are the
# ones with a street_* handler: Guard 0x60, Jester 0x64, Merchant 0x68, Fighter 0xF0,
# Cleric 0xF4, Wizard 0xF8, Thief 0xFC.
NPC = {0x60: 'Guard', 0x64: 'Jester', 0x68: 'Merchant', 0xF0: 'Fighter',
       0xF4: 'Cleric', 0xF8: 'Wizard', 0xFC: 'Thief'}

print('%-6s %-8s %-30s %s' % ('sector', 'shoprun', 'shop text', 'NPCs standing on/next to it'))
for path in sorted(glob.glob('original/mapx*')):
    sec = os.path.basename(path)[4:]
    mp = 'original/monx' + sec
    if not os.path.exists(mp):
        continue
    m = open(path, 'rb').read()[:4096]
    monx = open(mp, 'rb').read()
    if not any(monx[96:128]):
        continue
    npc = {}
    for i in range(32):
        t = monx[96 + i]
        if t in NPC:
            npc[(monx[i], monx[32 + i])] = NPC[t]

    # horizontal letter runs of >= 3
    runs = []
    for r in range(64):
        row = m[r * 64:(r + 1) * 64]
        c = 0
        while c < 64:
            if row[c] in LETTER:
                s, st = '', c
                while c < 64 and m[r * 64 + c] in LETTER:
                    s += LETTER[m[r * 64 + c]]
                    c += 1
                if len(s) >= 3:
                    runs.append((st, r, s))
            else:
                c += 1
    for st, r, s in runs:
        cells = [(c, r) for c in range(st, min(st + len(s), 64))]
        near = set()
        for (c, rr) in cells:
            for dc, dr in ((0, 0), (0, 1), (0, -1), (1, 0), (-1, 0)):
                k = (c + dc, rr + dr)
                if k in npc:
                    near.add(npc[k])
        if near:
            print('%-6s %-8s %-30s %s' % (sec, '%d,%d' % (st, r), s,
                                          ', '.join(sorted(near))))
