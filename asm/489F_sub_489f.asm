# sub_489f — mechanical clean (bulk wave); behavior not yet reviewed
# func 489F..48A6  len 0008 B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_489f:
L_004a9f:
        inc    %di
L_004aa0:
        .byte 0x8b,0xdf  # forced-kept: gas re-encodes 'mov    %di,%bx' differently
L_004aa2:
        cmp    $0x10,%bl
L_004aa5:
        jb L_004a64
