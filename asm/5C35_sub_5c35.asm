# sub_5c35 — mechanical clean (bulk wave); behavior not yet reviewed
# func 5C35..5C45  len 0011 B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_5c35:
L_005e35:
        .byte 0x8b,0xde  # forced-kept: gas re-encodes 'mov    %si,%bx' differently
L_005e37:
        mov    %bl,0x4
L_005e3b:
        incb   0x5
L_005e3f:
        mov    0x5,%al
L_005e42:
        cmp    $0xa,%al
L_005e44:
        je L_005e49
