# sub_469e — mechanical clean (bulk wave); behavior not yet reviewed
# func 469E..46AC  len 000F B  evidence: seed+reko
# calls: L_0053eb
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_469e:
L_00489e:
        mov    $0x0,%bh
L_0048a0:
        mov    $0x2,%bl
L_0048a2:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
L_0048a4:
        mov    $0x0,%bh
L_0048a6:
        mov    $0x7,%bl
L_0048a8:
        .byte 0x8b,0xf3  # forced-kept: gas re-encodes 'mov    %bx,%si' differently
L_0048aa:
        call L_0053eb
