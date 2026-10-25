# sub_475c — mechanical clean (bulk wave); behavior not yet reviewed
# func 475C..4762  len 0007 B  evidence: reko
# confidence: low (bytes proven by check_func.py)
# body corrected: 2026-10-28e -- evidence: the first three bytes are the tail of
#           `mov 0x76(%di),%al` whose opcode 0x8a is the forced-keep at asm/475B; gas cannot
#           encode that one (it shortens the displacement to `8a 45 76`), so the tail stays raw.
#           `test %si,0x0(%bp)` was those three bytes read as an instruction. Found by
#           tools/forced_keep_audit.py.
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_475c:
L_00495c:
        .byte 0x85, 0x76, 0x00   # tail of `mov 0x76(%di),%al` started at asm/475B
L_00495f:
        .byte 0x0a,0xc0  # forced-kept: gas re-encodes 'or     %al,%al' differently
L_004961:
        je L_00498b
