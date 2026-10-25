# sub_3dc5 — mechanical clean (bulk wave); behavior not yet reviewed
# func 3DC5..3DC6  len 0002 B  evidence: reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
# confidence: low (bytes proven by check_func.py)
# body corrected: 2026-10-28e -- evidence: both bytes are the displacement of `jmp L_000c33`
#           (`e9 6c cc`) whose opcode the map left at asm/3DC4; `insb` and `int3` were that
#           displacement read as two instructions. Found by tools/forced_keep_audit.py.
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_3dc5:
L_003fc5:
        .byte 0x6c, 0xcc   # tail of `jmp L_000c33` (stop-trunc) started at asm/3DC4
