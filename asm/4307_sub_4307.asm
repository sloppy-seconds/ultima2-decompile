# sub_4307 — mechanical clean (bulk wave); behavior not yet reviewed
# func 4307..4308  len 0002 B  evidence: reko
# confidence: low (bytes proven by check_func.py)
# confidence: low (bytes proven by check_func.py)
# body corrected: 2026-10-28e -- evidence: both bytes are the operand of `call L_002562`
#           (`e8 59 e0`) whose opcode the map left at asm/4306. `pop %cx` was the first operand
#           byte read as an instruction, and the `loopne 0x44aa` stop-trunc on the second was a
#           phantom: it implied a branch into asm/4309 and made the `mov 0x19,%al` gate there look
#           like branch target rather than the entry it is. Found by tools/forced_keep_audit.py.
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_4307:
L_004507:
        .byte 0x59, 0xe0   # tail of `call L_002562` (stop-trunc) started at asm/4306
