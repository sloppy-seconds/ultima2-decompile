# sub_3c02 — mechanical clean (bulk wave); behavior not yet reviewed
# func 3C02..3C03  len 0002 B  evidence: reko
# confidence: low (bytes proven by check_func.py)
# body corrected: 2026-10-28e -- evidence: both bytes are the displacement of `jmp L_000c33`
#           (`e9 2f ce`) whose opcode the map left at asm/3C01; `das` and `into` were that
#           displacement read as two instructions. Found by tools/forced_keep_audit.py.
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_3c02:
L_003e02:
        .byte 0x2f, 0xce   # tail of `jmp L_000c33` (stop-trunc) started at asm/3C01
