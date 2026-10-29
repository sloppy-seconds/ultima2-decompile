# dungeon_cell_gate — first third of the sweep's "may this creature enter that cell?", and
#           the fragment cut is why this looked like a stub returning a magic 0xFF.
# name-evidence: `mov 0x25,%al ; cmp 0x1b7(%di),%al ; je` past a `mov $0xff,%al`. So the
#           answer is 0xFF when the creature's own floor byte is not the player's floor,
#           and otherwise it FALLS THROUGH into asm/144C and asm/1451, which read the cell.
#           One function in three pieces: asm/143C (floor gate) -> asm/144C (supplies the
#           floor byte in AL) -> asm/1451_site_cell_open_on_floor (the page arithmetic).
#           The same cut-in-half failure that hid cmd_I, cmd_D and cmd_K, and the reason
#           tools/fragment_splits.py exists.
#           In a dungeon [DI+0x1B7] is NOT a kind index: asm/147F writes `slot >> 1` into
#           it, which over 32 slots is exactly floor 0..15. Same byte, other meaning, and
#           that is the dungeon/overworld quarantine being load-bearing rather than tidy.
#           The 0xFF return is indistinguishable from a cell that literally holds 0xFF.
#           Named rather than patched: the shipped maps cannot produce it, every authored
#           value being a multiple of 0x10 and every stamp 1..7.
# func 143C..144B  len 0010 B  evidence: call+reko
# provenance: static, read in full 2026-10-29 for G54 together with asm/144C and
#           asm/1451_site_cell_open_on_floor, which are the same function cut into three
#           by the Phase 2 map. Engine twin u2_dungeon_creatures()'s dg_probe_cell().
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_143c:
L_00163c:
        nop
L_00163d:
        mov    0x25,%al
L_001640:
        cmp    0x1b7(%di),%al
L_001644:
        je L_00164b
L_001646:
        mov    $0xff,%al
L_001648:
        .byte 0x0a,0xc0  # forced-kept: gas re-encodes 'or     %al,%al' differently
L_00164a:
        ret
L_00164b:
        nop
