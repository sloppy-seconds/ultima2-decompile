# sub_01fe — mechanical clean (bulk wave); behavior not yet reviewed
# func 01FE..01FF  len 0002 B  evidence: reko
# confidence: low (bytes proven by check_func.py)
# body corrected: 2026-10-28e -- evidence: both bytes are the operand of `call L_000888`
#           (`e8 88 04`) whose opcode the map left at asm/01FD; `mov %al,(%si)` was that operand
#           read as an instruction. Found by tools/forced_keep_audit.py.
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_01fe:
L_0003fe:
        .byte 0x88, 0x04   # tail of `call L_000888` (stop-trunc) started at asm/01FD
