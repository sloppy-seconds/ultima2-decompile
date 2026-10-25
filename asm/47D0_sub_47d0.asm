# sub_47d0 — mechanical clean (bulk wave); behavior not yet reviewed
# func 47D0..47DD  len 000E B  evidence: reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
# confidence: low (bytes proven by check_func.py)
# body corrected: 2026-10-28e -- evidence: the creature-slot sweep idiom (`mov $0x0,%bh /
#           mov 0x1f,%bl / mov %bx,%di / mov 0x96(%di),%al / call`), cut after the first opcode
#           at asm/47CF. Every mnemonic here was the sweep read from one byte early, including
#           the `or -0x17e0(%bx,%si),%si` forced-keep, which was the last byte of the call
#           displacement starting a new decode. Found by tools/forced_keep_audit.py.
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_47d0:
L_0049d0:
        .byte 0x00   # tail of `mov $0x0,%bh` started at asm/47CF
L_0049d1:
        mov    0x1f,%bl
L_0049d5:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
L_0049d7:
        .byte 0x8a,0x85,0x96,0x00  # forced-kept: gas re-encodes 'mov 0x96(%di),%al' differently
L_0049db:
        call L_0055b5
