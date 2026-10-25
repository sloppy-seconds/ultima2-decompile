# sub_4618 — mechanical clean (bulk wave); behavior not yet reviewed
# func 4618..461F  len 0008 B  evidence: reko
# calls: L_00528c
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
# confidence: low (bytes proven by check_func.py)
# body corrected: 2026-10-28e -- evidence: the first two bytes are the tail of the moffs form
#           `mov 0x62,%al` (`a0 62 00`) whose opcode is the forced-keep at asm/4617; `bound
#           %ax,(%bx,%si)` was those two bytes read as an instruction. gas encodes the moffs
#           move exactly, so the marker on 4617 blames gas for a boundary. Found by
#           tools/forced_keep_audit.py.
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_4618:
L_004818:
        .byte 0x62, 0x00   # tail of `mov 0x62,%al` (moffs `a0 62 00`) started at asm/4617
L_00481a:
        clc
L_00481b:
        adc    $0x1d,%al
L_00481d:
        call L_00528c
