# sub_17f0 — mechanical clean (bulk wave); behavior not yet reviewed
# func 17F0..17F1  len 0002 B  evidence: reko
# confidence: low (bytes proven by check_func.py)
# body corrected: 2026-10-28e -- evidence: both bytes are the displacement of `jmp L_000c33`
#           (`e9 41 f2`) whose opcode the map left at asm/17EF. The two forced-keeps were that
#           displacement read as instructions, and the second of them (`bnd call 0x51df`) is how
#           the `f2` prefix byte reached a mnemonic this binary never executes. Found by
#           tools/forced_keep_audit.py.
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_17f0:
L_0019f0:
        .byte 0x41, 0xf2   # tail of `jmp L_000c33` (stop-trunc) started at asm/17EF
