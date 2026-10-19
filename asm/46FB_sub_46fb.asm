# sub_46fb — mechanical clean (bulk wave); behavior not yet reviewed
# func 46FB..4709  len 000F B  evidence: seed+reko
# calls: L_0053eb
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_46fb:
L_0048fb:
        mov    $0x0,%bh
L_0048fd:
        mov    $0x1e,%bl
L_0048ff:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
L_004901:
        mov    $0x0,%bh
L_004903:
        mov    $0x6,%bl
L_004905:
        .byte 0x8b,0xf3  # forced-kept: gas re-encodes 'mov    %bx,%si' differently
L_004907:
        call L_0053eb
