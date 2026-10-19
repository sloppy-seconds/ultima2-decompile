# sub_507d — mechanical clean (bulk wave); behavior not yet reviewed
# func 507D..5084  len 0008 B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_507d:
L_00527d:
        .byte 0x8a,0x87,0x36,0x00  # forced-kept: gas re-encodes 'mov    0x36(%bx),%al' differently
L_005281:
        cmp    $0x0,%al
L_005283:
        je L_00528b
