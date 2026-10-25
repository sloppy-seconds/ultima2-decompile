# sub_4658 — mechanical clean (bulk wave); behavior not yet reviewed
# func 4658..465F  len 0008 B  evidence: reko
# calls: L_00528c
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
# confidence: low (bytes proven by check_func.py)
# body corrected: 2026-10-28e -- evidence: the first two bytes are the tail of the moffs form
#           `mov 0x63,%al` (`a0 63 00`) whose opcode is the forced-keep at asm/4657; `arpl
#           %ax,(%bx,%si)` was those two bytes read as an instruction. gas encodes the moffs
#           move exactly, so the marker on 4657 blames gas for a boundary. Found by
#           tools/forced_keep_audit.py.
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_4658:
L_004858:
        .byte 0x63, 0x00   # tail of `mov 0x63,%al` (moffs `a0 63 00`) started at asm/4657
L_00485a:
        clc
L_00485b:
        adc    $0x24,%al
L_00485d:
        call L_00528c
