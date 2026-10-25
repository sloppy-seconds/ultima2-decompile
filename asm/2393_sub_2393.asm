# sub_2393 — mechanical clean (bulk wave); behavior not yet reviewed
# func 2393..2394  len 0002 B  evidence: reko
# confidence: low (bytes proven by check_func.py)
# body corrected: 2026-10-28e -- evidence: both bytes are the displacement of `jmp L_000c30`
#           (`e9 9b e6`) whose opcode the map left at asm/2392. `fwait` was the 0x9b escape byte
#           read as an instruction and the `out %al,$0x90` forced-keep was its own displacement
#           byte starting a new decode — which is also why asm/2395 was misrecorded as a nop pad.
#           Found by tools/forced_keep_audit.py.
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_2393:
L_002593:
        .byte 0x9b, 0xe6   # tail of `jmp L_000c30` (stop-trunc) started at asm/2392
