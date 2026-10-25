# sub_4829 — mechanical clean (bulk wave); behavior not yet reviewed
# func 4829..4836  len 000E B  evidence: reko
# confidence: low (bytes proven by check_func.py)
# body corrected: 2026-10-28e -- evidence: this is the creature-slot sweep idiom that recurs
#           through the 47xx/48xx range — `mov $0x0,%bh / mov 0x1f,%bl / mov %bx,%di /
#           mov 0xNN(%di),%al / call` — and the map cut its first instruction after the opcode
#           at asm/4828. All four mnemonics this file showed were the sweep read from one byte
#           early. Found by tools/forced_keep_audit.py.
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_4829:
L_004a29:
        .byte 0x00   # tail of `mov $0x0,%bh` started at asm/4828
L_004a2a:
        mov    0x1f,%bl
L_004a2e:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
L_004a30:
        .byte 0x8a,0x85,0xb6,0x00  # forced-kept: gas re-encodes 'mov 0xb6(%di),%al' differently
L_004a34:
        call L_0055b5
