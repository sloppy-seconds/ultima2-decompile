# sub_4207 — mechanical clean (bulk wave); behavior not yet reviewed
# func 4207..4208  len 0002 B  evidence: reko
# confidence: low (bytes proven by check_func.py)
# body corrected: 2026-10-28e -- evidence: both bytes are the displacement of `jmp L_0042a6`
#           (`e9 9d fe`) whose opcode the map left at asm/4206. The two forced-keeps were that
#           displacement read as instructions, one of which objdump had no mnemonic for at all.
#           Found by tools/forced_keep_audit.py.
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_4207:
L_004407:
        .byte 0x9d, 0xfe   # tail of `jmp L_0042a6` (stop-trunc) started at asm/4206
