# sub_47b5 — mechanical clean (bulk wave); behavior not yet reviewed
# func 47B5..47BB  len 0007 B  evidence: reko
# confidence: low (bytes proven by check_func.py)
# body corrected: 2026-10-28e -- evidence: the first three bytes are the tail of
#           `mov 0x96(%di),%al` whose opcode 0x8a is the forced-keep at asm/47B4 (gas shortens
#           the displacement to `8a 45 96`, so the tail stays raw). `test %dx,0xa00(%bp)` and
#           the `shlb` forced-keep after it were those bytes plus the real `or`/`je` read from
#           the wrong offset. Found by tools/forced_keep_audit.py.
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_47b5:
L_0049b5:
        .byte 0x85, 0x96, 0x00   # tail of `mov 0x96(%di),%al` started at asm/47B4
L_0049b8:
        .byte 0x0a,0xc0  # forced-kept: gas re-encodes 'or     %al,%al' differently
L_0049ba:
        je L_0049e3
