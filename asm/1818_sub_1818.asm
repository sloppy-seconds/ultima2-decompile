# sub_1818 — mechanical clean (bulk wave); behavior not yet reviewed
# func 1818..1819  len 0002 B  evidence: reko
# confidence: low (bytes proven by check_func.py)
# body corrected: 2026-10-28e -- evidence: both bytes are the operand of `call L_002252`
#           (`e8 38 08`) whose opcode the map left at asm/1817; `cmp %cl,(%bx,%si)` was that
#           operand read as an instruction. Found by tools/forced_keep_audit.py.
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_1818:
L_001a18:
        .byte 0x38, 0x08   # tail of `call L_002252` (stop-trunc) started at asm/1817
