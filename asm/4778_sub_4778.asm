# sub_4778 — mechanical clean (bulk wave); behavior not yet reviewed
# func 4778..4785  len 000E B  evidence: reko
# calls: L_0055b5
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
# confidence: low (bytes proven by check_func.py)
# body corrected: 2026-10-28e -- evidence: the creature-slot sweep idiom (`mov $0x0,%bh /
#           mov 0x1f,%bl / mov %bx,%di / mov 0x76(%di),%al / call`), cut after the first opcode
#           at asm/4777. All four mnemonics this file showed were the sweep read from one byte
#           early. Found by tools/forced_keep_audit.py.
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_4778:
L_004978:
        .byte 0x00   # tail of `mov $0x0,%bh` started at asm/4777
L_004979:
        mov    0x1f,%bl
L_00497d:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
L_00497f:
        .byte 0x8a,0x85,0x76,0x00  # forced-kept: gas re-encodes 'mov 0x76(%di),%al' differently
L_004983:
        call L_0055b5
