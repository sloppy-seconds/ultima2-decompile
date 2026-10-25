# sub_488c — mechanical clean (bulk wave); behavior not yet reviewed
# func 488C..4899  len 000E B  evidence: reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
# confidence: low (bytes proven by check_func.py)
# body corrected: 2026-10-28e -- evidence: the creature-slot sweep idiom (`mov $0x0,%bh /
#           mov 0x1f,%bl / mov %bx,%di / mov 0xd6(%di),%al / call`), cut after the first opcode
#           at asm/488B. Every mnemonic here was the sweep read from one byte early. Found by
#           tools/forced_keep_audit.py.
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_488c:
L_004a8c:
        .byte 0x00   # tail of `mov $0x0,%bh` started at asm/488B
L_004a8d:
        mov    0x1f,%bl
L_004a91:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
L_004a93:
        .byte 0x8a,0x85,0xd6,0x00  # forced-kept: gas re-encodes 'mov 0xd6(%di),%al' differently
L_004a97:
        call L_0055b5
