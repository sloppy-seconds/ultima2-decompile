# sub_467a — mechanical clean (bulk wave); behavior not yet reviewed
# func 467A..467E  len 0005 B  evidence: reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
# confidence: low (bytes proven by check_func.py)
# body corrected: 2026-10-28e -- evidence: the first two bytes are the tail of the moffs form
#           `mov 0x66,%al` (`a0 66 00`) whose opcode is the forced-keep at asm/4679, and the
#           three after them are a complete `call L_0055b5` the old decode split into a `data32`
#           prefix and an `ss or $0xb7,%ax` forced-keep. gas encodes the moffs move exactly.
#           Found by tools/forced_keep_audit.py.
# calls: L_0055b5
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_467a:
L_00487a:
        .byte 0x66, 0x00   # tail of `mov 0x66,%al` (moffs `a0 66 00`) started at asm/4679
L_00487c:
        call L_0055b5
