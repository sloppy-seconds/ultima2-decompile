# name_pool — the indexed name pool: eighteen location descriptions, then weapons, armour,
#           spells, items, stats, races and classes. DATA, not code.
# body corrected: 2026-10-25 -- evidence: the bytes refute the old decode rather than
#           extending it. The clean wave entered this span as code, so a NUL-separated string
#           table came out as alternating fragments and invented instructions: the
#           `add %al,0x41(%si)` sitting above `db "GGER"` is the previous string's terminating
#           NUL plus the first byte of the next one, which is how DAGGER arrived as "GGER",
#           MACE as "CE" and SWORD as "ORD". Re-derived from original/ultimaii.exe file
#           0x4E55..0x5108 by splitting on NUL, entry by entry, each one asserted against the
#           image before it was written. The split is confirmed independently: every group base
#           documented in docs/status-screen-z.md section 7 lands on the right entry — 19
#           HANDS, 29 SKIN, 36 NONE, 46 RING, 62 STRENGTH, 68 HUMAN, 72 FIGHTER — which is the
#           same arithmetic that makes readied_weapon 9 print QUICK SWORD at pool[28].
#           tools/assemble_clean.sh re-assembles the tree and the whole-binary md5 is
#           unchanged, so this corrects the decode and not the bytes.
# name-evidence: asm/508C takes the entry index in AL and is called from the Z-screen print
#           sites CS:0x47c4 (WEAPON-), CS:0x47fb (ARMOUR-) and CS:0x483c (SPELL-). The first
#           eighteen entries are the location descriptions, "IN THE WATER." through
#           "ON COBBLE.", which is the only thing that ever made this look like a
#           plane-landing routine.
# pool[0] IS AN EMPTY ENTRY: the byte before "IN THE WATER." is a second NUL and the code's
#           index base counts it. That single fact is what makes HANDS index 19 rather than 18,
#           and engine/tools/extract/extractor.py asserts it (POOL_ANCHOR_INDEX) instead of
#           trusting a lucky split. When there is no exe to read, the extractor now parses this
#           file one entry per line and requires the pool[N] tags to run 0..N with no gap, so a
#           drift here fails the build rather than putting PHASER where QUICK SWORD belongs.
# licensing: this is game text and it is committed on purpose — AGENTS.md section 0, the
#           text/art line. A byte-exact reconstruction of the executable necessarily contains
#           the strings the executable contains, and the i18n TODO in that section wants these
#           entries addressable per item, which is what the per-entry labels and pool[N] tags
#           are for.
# func 4C55..4F08  len 02B4 B  evidence: re-derived from the image 2026-10-25
# provenance: static. The old header claimed "entry executed in 23 of 60 harvests", which was
#           a count against a 60-harvest corpus and has aged the same way cmd_handlers' did —
#           and there is no entry point here to execute at all.
# confidence: high (bytes, and the documented bases agree with the decode independently)
L_004e55:
        db 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00        # alignment pad, 11 bytes, before pool[0]
L_004e60:
        db 0x00        # pool[0]  (carries no text)
L_004e61:
        db "IN THE WATER.",0x00        # pool[1]
L_004e6f:
        db "IN A MARSH.",0x00        # pool[2]
L_004e7b:
        db "ON GRASS.",0x00        # pool[3]
L_004e85:
        db "IN WOODS.",0x00        # pool[4]
L_004e8f:
        db "IN THE MTS.",0x00        # pool[5]
L_004e9b:
        db "NEAR A VILLAGE.",0x00        # pool[6]
L_004eab:
        db "NEAR A TOWNE.",0x00        # pool[7]
L_004eb9:
        db "NEAR A TOWER.",0x00        # pool[8]
L_004ec7:
        db "NEAR A CASTLE.",0x00        # pool[9]
L_004ed6:
        db "NEAR A DUNGEON.",0x00        # pool[10]
L_004ee6:
        db "NEAR A SIGN.",0x00        # pool[11]
L_004ef3:
        db "NEAR A HORSE.",0x00        # pool[12]
L_004f01:
        db "NEAR A FRIGATE.",0x00        # pool[13]
L_004f11:
        db "NEAR A PLANE.",0x00        # pool[14]
L_004f1f:
        db "NEAR A ROCKET.",0x00        # pool[15]
L_004f2e:
        db "NEAR ARMOUR.",0x00        # pool[16]
L_004f3b:
        db "NEAR A HOLE.",0x00        # pool[17]
L_004f48:
        db "ON COBBLE.",0x00        # pool[18]
L_004f53:
        db "HANDS",0x00        # pool[19]  <- weapons  (pool[19 + DS:61])
L_004f59:
        db "DAGGER",0x00        # pool[20]
L_004f60:
        db "MACE",0x00        # pool[21]
L_004f65:
        db "AXE",0x00        # pool[22]
L_004f69:
        db "BOW",0x00        # pool[23]
L_004f6d:
        db "SWORD",0x00        # pool[24]
L_004f73:
        db "GREAT SWORD",0x00        # pool[25]
L_004f7f:
        db "LIGHT SWORD",0x00        # pool[26]
L_004f8b:
        db "PHASER",0x00        # pool[27]
L_004f92:
        db "QUICK SWORD",0x00        # pool[28]
L_004f9e:
        db "SKIN",0x00        # pool[29]  <- armour   (pool[29 + DS:62])
L_004fa3:
        db "CLOTH",0x00        # pool[30]
L_004fa9:
        db "LEATHER",0x00        # pool[31]
L_004fb1:
        db "CHAIN",0x00        # pool[32]
L_004fb7:
        db "PLATE",0x00        # pool[33]
L_004fbd:
        db "REFLECT",0x00        # pool[34]
L_004fc5:
        db "POWER",0x00        # pool[35]
L_004fcb:
        db "NONE",0x00        # pool[36]  <- spells   (pool[36 + DS:63])
L_004fd0:
        db "LIGHT",0x00        # pool[37]
L_004fd6:
        db "DOWN LADDER",0x00        # pool[38]
L_004fe2:
        db "UP LADDER",0x00        # pool[39]
L_004fec:
        db "PASSWALL",0x00        # pool[40]
L_004ff5:
        db "SURFACE",0x00        # pool[41]
L_004ffd:
        db "PRAYER",0x00        # pool[42]
L_005004:
        db "MAGIC MISSILE",0x00        # pool[43]
L_005012:
        db "BLINK",0x00        # pool[44]
L_005018:
        db "KILL",0x00        # pool[45]
L_00501d:
        db "RING",0x00        # pool[46]  <- items    (pool[0x2e + index])
L_005022:
        db "WAND",0x00        # pool[47]
L_005027:
        db "STAFF",0x00        # pool[48]
L_00502d:
        db "BOOTS",0x00        # pool[49]
L_005033:
        db "CLOAK",0x00        # pool[50]
L_005039:
        db "HELM",0x00        # pool[51]
L_00503e:
        db "GEM",0x00        # pool[52]
L_005042:
        db "ANKH",0x00        # pool[53]
L_005047:
        db "RED GEM",0x00        # pool[54]
L_00504f:
        db "SKULL KEY",0x00        # pool[55]
L_005059:
        db "GREEN GEM",0x00        # pool[56]
L_005063:
        db "BRASS BUTTON",0x00        # pool[57]
L_005070:
        db "BLUE TASSLE",0x00        # pool[58]
L_00507c:
        db "STRANGE COIN",0x00        # pool[59]
L_005089:
        db "GREEN IDOL",0x00        # pool[60]
L_005094:
        db "TRI-LITHIUM",0x00        # pool[61]
L_0050a0:
        db "STRENGTH",0x00        # pool[62]  <- stats    (the six names come as literals 0x3E..0x43)
L_0050a9:
        db "AGILITY",0x00        # pool[63]
L_0050b1:
        db "STAMINA",0x00        # pool[64]
L_0050b9:
        db "CHARISMA",0x00        # pool[65]
L_0050c2:
        db "WISDOM",0x00        # pool[66]
L_0050c9:
        db "INTELL.",0x00        # pool[67]
L_0050d1:
        db "HUMAN",0x00        # pool[68]  <- races    (pool[0x44 + index])
L_0050d7:
        db "ELF",0x00        # pool[69]
L_0050db:
        db "DWARF",0x00        # pool[70]
L_0050e1:
        db "HOBBIT",0x00        # pool[71]
L_0050e8:
        db "FIGHTER",0x00        # pool[72]  <- classes  (pool[0x48 + index])
L_0050f0:
        db "CLERIC",0x00        # pool[73]
L_0050f7:
        db "WIZARD",0x00        # pool[74]
L_0050fe:
        db "THIEF",0x00        # pool[75]
L_005104:
        db 0x00,0x00,0x00,0x00,0x00        # five further NULs: empty entries or padding, not settled
