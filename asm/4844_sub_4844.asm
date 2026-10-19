# sub_4844 — mechanical clean (bulk wave); behavior not yet reviewed
# func 4844..4852  len 000F B  evidence: seed+reko
# calls: L_0053eb
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_4844:
L_004a44:
        mov    $0x0,%bh
L_004a46:
        mov    $0x1,%bl
L_004a48:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
L_004a4a:
        mov    $0x0,%bh
L_004a4c:
        mov    $0x12,%bl
L_004a4e:
        .byte 0x8b,0xf3  # forced-kept: gas re-encodes 'mov    %bx,%si' differently
L_004a50:
        call L_0053eb
