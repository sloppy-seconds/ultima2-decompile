# dungeon_cell_gate_tail — middle third of the sweep's cell gate: it puts the CREATURE's
#           floor byte in AL and falls through into asm/1451's page arithmetic.
# name-evidence: one instruction, `mov 0x1b7(%di),%al`, and then no ret — the next fragment
#           at asm/1451_site_cell_open_on_floor begins `mov %al,%ah` and uses AL as the
#           floor multiplier of floor*256. Read alone this is a stub; read with its two
#           neighbours it is the line that says a dungeon creature is looked up on its own
#           page, not the player's. See asm/143C_dungeon_cell_gate for the whole chain.
# func 144C..1450  len 0005 B  evidence: call+reko
# provenance: static, read in full 2026-10-29 for G54; its identity as the floor-byte
#           supplier is asm/1451's `mov %al,%ah` using AL as the floor*256 multiplier.
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_144c:
L_00164c:
        nop
L_00164d:
        mov    0x1b7(%di),%al
