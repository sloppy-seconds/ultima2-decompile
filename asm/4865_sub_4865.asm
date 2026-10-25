# sub_4865 — mechanical clean (bulk wave); behavior not yet reviewed
# func 4865..486B  len 0007 B  evidence: reko
# confidence: low (bytes proven by check_func.py)
# body corrected: 2026-10-28e -- evidence: the first three bytes are the tail of
#           `mov 0xd6(%di),%al` whose opcode 0x8a is the forced-keep at asm/4864 (gas shortens
#           the displacement, so the tail stays raw). `test %dx,%si`, `add %cl,(%bp,%si)` and
#           the `shlb` forced-keep were those bytes plus the real `or`/`je` read from the wrong
#           offset. Found by tools/forced_keep_audit.py.
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_4865:
L_004a65:
        .byte 0x85, 0xd6, 0x00   # tail of `mov 0xd6(%di),%al` started at asm/4864
L_004a68:
        .byte 0x0a,0xc0  # forced-kept: gas re-encodes 'or     %al,%al' differently
L_004a6a:
        je L_004a9f
