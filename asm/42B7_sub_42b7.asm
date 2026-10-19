# sub_42b7 — mechanical clean (bulk wave); behavior not yet reviewed
# func 42B7..42C0  len 000A B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_42b7:
L_0044b7:
        mov    $0x0,%bh
L_0044b9:
        mov    $0x2,%bl
L_0044bb:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
L_0044bd:
        cmp    $0x75,%al
L_0044bf:
        jb L_0044d1
