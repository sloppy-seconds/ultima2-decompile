# sub_478b — mechanical clean (bulk wave); behavior not yet reviewed
# func 478B..4792  len 0008 B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_478b:
L_00498b:
        inc    %di
L_00498c:
        .byte 0x8b,0xdf  # forced-kept: gas re-encodes 'mov    %di,%bx' differently
L_00498e:
        cmp    $0xa,%bl
L_004991:
        jb L_00495b
