# creature_step_gate — may this creature step onto the cell staged in DS:23/DS:24?
# name-evidence: entry is `mov %al,0x1f` one instruction after `call L_0052b3`
#           (asm/50B3_map_tile_ptr), so AL on entry is the sector-grid tile byte of the
#           staged cell. Two returns: L_0023f7 `mov $0x0,%al; cmp $0x0,%al; ret` and
#           L_0023fc `mov $0xff,%al; cmp $0x0,%al; ret`. The trailing cmp is the contract:
#           the callers at asm/2150, asm/2169 and asm/2189 branch on ZF, so
#           **AL = 0 accept / AL = 0xFF refuse**, and ZF is the flag the callers read.
# REAL FUNCTION SPAN: runtime 2199..2200 (file 2399..2400). The `# func` line below
#           declares only this fragment's 10 bytes; the body continues through
#           asm/21A3 .. asm/21FC, all of which are parts of this one predicate.
#
# THE RULE, complete (decoded 2026-10-28; the full table with grades is
#           docs/contract-creature-tick.md § "The step gate"):
#             if DS:26A != 0            -> refuse, unconditionally (asm/21A3)
#             if kind in {0x2C, 0x48}   -> accept iff tile == 0x00 (asm/21A6, 21AE, 21D8)
#             else:
#                 if kind < 0x78 and tile == 0x5C -> accept   (asm/21B2, 21B6)
#                 if tile in {0x10, 0x04, 0x00}   -> refuse   (asm/21BD, 21C5, 21C9)
#                 if tile < 0x14                  -> accept   (asm/21CD, jb: 0x08, 0x0C)
#                 if tile == 0x70                 -> accept   (asm/21D1)
#                 otherwise                       -> refuse   (asm/21D5)
#             accept then passes a site guard: if DS:4A != 0, candidate x == 0 or
#           candidate y == 0 is refused (asm/21E2, 21E9, 21F0). In the wilderness
#           (DS:4A == 0) the 64x64 grid wraps and the edge row/column is walkable.
#         Reads DS:1F (the tile, stored by this routine's first instruction),
#         DS:197[DI] (mon_type), DS:26A, DS:4A, DS:23, DS:24. Writes DS:1F only.
#         Of the 64 tile bytes that ever occur in a sector map (all multiples of 4,
#           docs/passability-findings.md F12) exactly five are ever accepted: 0x08, 0x0C,
#           0x5C, 0x70 and — for the two water kinds only — 0x00.
# 0x5C IS THE FORCE FIELD, settled live 2026-10-28 (captures/spice86/g29-field). It is art
#           0x17 (checkerboard rows), 72 cells in mapx03 and 4 in mapx71, and it is the only
#           clause that splits on kind. Standing on it with no ring costs exactly 1000 HP,
#           observed six times; with the ring (DS:D6 != 0) it costs nothing; a plain 0x70 step
#           costs nothing. So the gate's reading is: monsters cross force fields, the four NPC
#           classes (Fighter/Cleric/Wizard/Thief, mon_type >= 0x78) may not. Same commit
#           corrects docs/phase4-state.md § CP5, which had ruled a tile trigger out on a units
#           error — it searched mapx00 for the MODE byte 0x2e, which is map_byte >> 1, and map
#           bytes are multiples of 4.
# label: kept as sub_2199 on purpose — labels are body and CP0 md5s them
# func 2199..21A2  len 000A B  evidence: seed+call+reko
# provenance: static, decoded from asm/2199..asm/21FC in address order 2026-10-28
# confidence: high for the bytes and the verdict polarity (both returns are in the bytes
#           and three callers branch on them); medium for the species reading, which
#           depends on mon_type>>2 being the art index (docs/art-index.md)
sub_2199:
L_002399:
        mov    %al,0x1f
L_00239c:
        mov    0x26a,%al
L_00239f:
        cmp    $0x0,%al
L_0023a1:
        je L_0023a6
