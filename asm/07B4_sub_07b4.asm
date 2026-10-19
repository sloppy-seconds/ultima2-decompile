# sub_07b4 — mechanical clean (bulk wave); behavior not yet reviewed
# func 07B4..07C2  len 000F B  evidence: seed+reko
# calls: L_0053eb
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_07b4:
L_0009b4:
        mov    $0x0,%bh
L_0009b6:
        mov    $0xc,%bl
L_0009b8:
        .byte 0x8b,0xf3  # forced-kept: gas re-encodes 'mov    %bx,%si' differently
L_0009ba:
        mov    $0x0,%bh
L_0009bc:
        mov    $0xa,%bl
L_0009be:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
L_0009c0:
        call L_0053eb
