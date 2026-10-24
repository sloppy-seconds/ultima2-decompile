# speed_delay_lookup — read one of the 20 machine-scaled delay slots into %bx
# name-evidence: `mov 0x580(%bx),%bx` — %bx goes in as a byte offset into the word table at
#           DS:580 and comes out as the value stored there. The table is written by the rescale
#           routine at asm/06ED..0710 (`mov %ax,0x580(%bx)`), which fills offsets 0x00..0x26 in
#           steps of 2, i.e. exactly 20 slots. Callers set %bx to a small even constant first —
#           observed 0x00, 0x08, 0x0a, 0x14, 0x16, 0x18 — which is an index, not a value.
# WHY IT IS WORTH A NAME: this is the single read path for the whole speed system, and it is
#           called from FOURTEEN routines (asm/022E, 0696, 08C8, 2557, 2587, 2593, 277B,
#           38B0_cmd_L, 421A, 5F08, 6999_space_status, 6DFD_hyperwarp_flow, 7030_space_collision,
#           72A0). Whatever the game does at animation pace — the hyperwarp countdown, the space
#           status crawl, key-wait timeouts — it takes its timing from here.
# what the value is used as: a duration, not a distance. asm/6DFD_hyperwarp_flow does
#           `call L_006d3d ; mov $0x16,%bx ; call L_000911` then `decb 0x4c8 ; jne`, and
#           asm/6999_space_status does the same shape then `call L_00514d ; cmp $0xff,%ah`,
#           which is a key wait with a timeout. Different slots are different lengths of pause.
# provenance: static, decoded 2026-10-28d from the listing; bytes proven by tools/check_func.py.
#           The 14-caller count is measured by grep over asm/, not asserted.
# confidence: high for the mechanism; the per-slot meaning of each of the 20 offsets is NOT known
#           and is the next step, not this claim
# label: kept as sub_0711 on purpose — labels are body and CP0 md5s them
# func 0711..0714  len 0004 B  evidence: seed+call+reko
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_0711:
L_000911:
        mov    0x580(%bx),%bx
