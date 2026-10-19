# sub_46bd — mechanical clean (bulk wave); behavior not yet reviewed
# func 46BD..46CB  len 000F B  evidence: seed+reko
# calls: L_0053eb
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_46bd:
L_0048bd:
        mov    $0x0,%bh
L_0048bf:
        mov    $0x10,%bl
L_0048c1:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
L_0048c3:
        mov    $0x0,%bh
L_0048c5:
        mov    $0x6,%bl
L_0048c7:
        .byte 0x8b,0xf3  # forced-kept: gas re-encodes 'mov    %bx,%si' differently
L_0048c9:
        call L_0053eb
