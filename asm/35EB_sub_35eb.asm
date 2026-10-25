# sub_35eb — mechanical clean (bulk wave); behavior not yet reviewed
# func 35EB..35EC  len 0002 B  evidence: reko
# confidence: low (bytes proven by check_func.py)
# body corrected: 2026-10-28e -- evidence: both bytes are the operand of `call L_002562`
#           (`e8 75 ed`) whose opcode the map left at asm/35EA; `jne L_0037da` was that operand
#           read as an instruction. Found by tools/forced_keep_audit.py.
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_35eb:
L_0037eb:
        .byte 0x75, 0xed   # tail of `call L_002562` (stop-trunc) started at asm/35EA
