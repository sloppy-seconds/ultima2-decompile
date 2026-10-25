# sub_47e1 — mechanical clean (bulk wave); behavior not yet reviewed
# func 47E1..47E2  len 0002 B  evidence: reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
# confidence: low (bytes proven by check_func.py)
# body corrected: 2026-10-28e -- evidence: both bytes are the operand of `call L_0055f4`
#           (`e8 11 0c`) whose opcode the map left at asm/47E0; `adc %cx,(%si)` was that operand
#           read as an instruction. Found by tools/forced_keep_audit.py.
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_47e1:
L_0049e1:
        .byte 0x11, 0x0c   # tail of `call L_0055f4` (stop-trunc) started at asm/47E0
