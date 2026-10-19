# sub_483c — mechanical clean (bulk wave); behavior not yet reviewed
# func 483C..4841  len 0006 B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_483c:
L_004a3c:
        inc    %di
L_004a3d:
        .byte 0x8b,0xdf  # forced-kept: gas re-encodes 'mov    %di,%bx' differently
L_004a3f:
        cmp    $0xa,%bl
