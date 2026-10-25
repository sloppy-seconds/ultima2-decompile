# sub_480d — mechanical clean (bulk wave); behavior not yet reviewed
# func 480D..4813  len 0007 B  evidence: reko
# confidence: low (bytes proven by check_func.py)
# body corrected: 2026-10-28e -- evidence: the first three bytes are the tail of
#           `mov 0xb6(%di),%al` whose opcode 0x8a is the forced-keep at asm/480C (gas shortens
#           the displacement, so the tail stays raw). `test %si,0xa00(%bp)` and the `shlb`
#           forced-keep after it were those bytes plus the real `or`/`je` read from the wrong
#           offset. Found by tools/forced_keep_audit.py.
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_480d:
L_004a0d:
        .byte 0x85, 0xb6, 0x00   # tail of `mov 0xb6(%di),%al` started at asm/480C
L_004a10:
        .byte 0x0a,0xc0  # forced-kept: gas re-encodes 'or     %al,%al' differently
L_004a12:
        je L_004a3c
