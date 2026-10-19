# sub_5b5d — mechanical clean (bulk wave); behavior not yet reviewed
# func 5B5D..5B6D  len 0011 B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_5b5d:
L_005d5d:
        .byte 0x8b,0xde  # forced-kept: gas re-encodes 'mov    %si,%bx' differently
L_005d5f:
        mov    %bl,0x4
L_005d63:
        incb   0x5
L_005d67:
        mov    0x5,%al
L_005d6a:
        cmp    $0xa,%al
L_005d6c:
        je L_005d71
