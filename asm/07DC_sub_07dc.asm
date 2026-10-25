# sub_07dc — mechanical clean (bulk wave); behavior not yet reviewed
# func 07DC..07DD  len 0002 B  evidence: reko
# confidence: low (bytes proven by check_func.py)
# body corrected: 2026-10-28e -- evidence: both bytes are the operand of `call L_00514d`
#           (`e8 6f 47`) whose opcode the map left at asm/07DB; `outsw` and `inc %di` were that
#           operand read as two instructions. Found by tools/forced_keep_audit.py.
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_07dc:
L_0009dc:
        .byte 0x6f, 0x47   # tail of `call L_00514d` (stop-trunc) started at asm/07DB
