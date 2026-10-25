# sub_4887 — mechanical clean (bulk wave); behavior not yet reviewed
# func 4887..488A  len 0004 B  evidence: reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
# confidence: low (bytes proven by check_func.py)
# body corrected: 2026-10-28e -- evidence: the first two bytes are the operand of
#           `call L_0051df` (`e8 56 07`) whose opcode the map left at asm/4886; `push %si` and
#           `pop %es` were that operand read as two instructions. The `sub $0xb700,%ax`
#           forced-keep after them is a second truncation of its own and is left alone here.
#           Found by tools/forced_keep_audit.py.
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_4887:
L_004a87:
        .byte 0x56, 0x07   # tail of `call L_0051df` (stop-trunc) started at asm/4886
L_004a89:
        .byte 0x2d,0x00  # forced-kept: gas re-encodes 'sub    $0xb700,%ax' differently
