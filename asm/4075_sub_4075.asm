# sub_4075 — mechanical clean (bulk wave); behavior not yet reviewed
# func 4075..407B  len 0007 B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_4075:
L_004275:
        .byte 0x8b,0xdf  # forced-kept: gas re-encodes 'mov    %di,%bx' differently
L_004277:
        cmp    $0x0,%bl
L_00427a:
        jne L_0042c0
