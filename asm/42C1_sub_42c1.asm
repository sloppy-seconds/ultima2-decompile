# sub_42c1 — mechanical clean (bulk wave); behavior not yet reviewed
# func 42C1..42CA  len 000A B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_42c1:
L_0044c1:
        mov    $0x0,%bh
L_0044c3:
        mov    $0x1,%bl
L_0044c5:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
L_0044c7:
        cmp    $0x99,%al
L_0044c9:
        jb L_0044d1
