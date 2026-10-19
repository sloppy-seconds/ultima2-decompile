# sub_471a — mechanical clean (bulk wave); behavior not yet reviewed
# func 471A..4728  len 000F B  evidence: seed+reko
# calls: L_0053eb
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_471a:
L_00491a:
        mov    $0x0,%bh
L_00491c:
        mov    $0x1d,%bl
L_00491e:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
L_004920:
        mov    $0x0,%bh
L_004922:
        mov    $0x7,%bl
L_004924:
        .byte 0x8b,0xf3  # forced-kept: gas re-encodes 'mov    %bx,%si' differently
L_004926:
        call L_0053eb
