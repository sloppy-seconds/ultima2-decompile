# sub_464b — mechanical clean (bulk wave); behavior not yet reviewed
# func 464B..464C  len 0002 B  evidence: reko
# confidence: low (bytes proven by check_func.py)
# body corrected: 2026-10-28e -- evidence: these two bytes are the operand of the `call L_0053eb`
#           whose opcode the map left at asm/463E; `sahf` was 0x9e read as an instruction and the
#           forced-keep was 0x0b read as the start of another one. Found by
#           tools/forced_keep_audit.py.
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_464b:
L_00484b:
        .byte 0x9e, 0x0b   # tail of `call L_0053eb` (stop-trunc) started at asm/463E
