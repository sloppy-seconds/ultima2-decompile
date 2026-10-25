# sub_45f6 — mechanical clean (bulk wave); behavior not yet reviewed
# func 45F6..45FA  len 0005 B  evidence: reko
# confidence: low (bytes proven by check_func.py)
# body corrected: 2026-10-28e -- evidence: the first two bytes are the tail of the moffs form
#           `mov 0x64,%al` (`a0 64 00`) whose opcode is the forced-keep at asm/45F5, and the
#           three after them are a complete `call L_0055b5` that the old decode split into
#           `fs add %ch,%al` and a `mov $0xb70d,%dx` forced-keep. gas encodes the moffs move
#           exactly, so the marker on 45F5 blames gas for a boundary. Found by
#           tools/forced_keep_audit.py.
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_45f6:
L_0047f6:
        .byte 0x64, 0x00   # tail of `mov 0x64,%al` (moffs `a0 64 00`) started at asm/45F5
L_0047f8:
        call L_0055b5
