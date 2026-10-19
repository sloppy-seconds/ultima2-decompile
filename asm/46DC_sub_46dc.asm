# sub_46dc — mechanical clean (bulk wave); behavior not yet reviewed
# func 46DC..46EA  len 000F B  evidence: seed+reko
# calls: L_0053eb
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_46dc:
L_0048dc:
        mov    $0x0,%bh
L_0048de:
        mov    $0xf,%bl
L_0048e0:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
L_0048e2:
        mov    $0x0,%bh
L_0048e4:
        mov    $0x7,%bl
L_0048e6:
        .byte 0x8b,0xf3  # forced-kept: gas re-encodes 'mov    %bx,%si' differently
L_0048e8:
        call L_0053eb
