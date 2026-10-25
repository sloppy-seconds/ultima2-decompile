# sub_2395 — mechanical clean (bulk wave); behavior not yet reviewed
# func 2395..2395  len 0001 B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# body corrected: 2026-10-28e -- evidence: this byte is not padding. The map cut `out %al,$0x90`
#           (`e6 90`) after its opcode at asm/2393, so 2395 is the operand of a real instruction
#           and `nop` was that operand read as code. The old header, disasm/defects.md and
#           disasm/phase2-summary.md all recorded this as a NOP-padding seed and a Reko failure
#           to be skipped; the disposition was a plausible story about a byte nobody had
#           re-read after the boundary was drawn. Found by tools/forced_keep_audit.py.
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_2395:
L_002595:
        .byte 0x90   # tail of `out %al,$0x90` started at asm/2393
