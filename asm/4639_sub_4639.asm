# sub_4639 — mechanical clean (bulk wave); behavior not yet reviewed
# func 4639..463D  len 0005 B  evidence: reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
# confidence: low (bytes proven by check_func.py)
# body corrected: 2026-10-28e -- evidence: the first two bytes are the tail of the moffs form
#           `mov 0x65,%al` (`a0 65 00`) whose opcode is the forced-keep at asm/4638, and the
#           three after them are a complete `call L_0055b5` the old decode split into a `gs`
#           prefix and a `ja`. gas encodes the moffs move exactly. Found by
#           tools/forced_keep_audit.py.
# calls: L_0055b5
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_4639:
L_004839:
        .byte 0x65, 0x00   # tail of `mov 0x65,%al` (moffs `a0 65 00`) started at asm/4638
L_00483b:
        call L_0055b5
