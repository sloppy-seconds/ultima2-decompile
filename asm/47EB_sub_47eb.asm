# sub_47eb — mechanical clean (bulk wave); behavior not yet reviewed
# func 47EB..47F9  len 000F B  evidence: seed+reko
# calls: L_0053eb
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_47eb:
L_0049eb:
        mov    $0x0,%bh
L_0049ed:
        mov    $0x1,%bl
L_0049ef:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
L_0049f1:
        mov    $0x0,%bh
L_0049f3:
        mov    $0xe,%bl
L_0049f5:
        .byte 0x8b,0xf3  # forced-kept: gas re-encodes 'mov    %bx,%si' differently
L_0049f7:
        call L_0053eb
