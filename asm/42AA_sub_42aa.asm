# sub_42aa — mechanical clean (bulk wave); behavior not yet reviewed
# func 42AA..42B6  len 000D B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_42aa:
L_0044aa:
        mov    0x51,%al
L_0044ad:
        mov    $0x0,%bh
L_0044af:
        mov    $0x3,%bl
L_0044b1:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
L_0044b3:
        cmp    $0x50,%al
L_0044b5:
        jb L_0044d1
