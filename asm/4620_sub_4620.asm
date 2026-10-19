# sub_4620 — mechanical clean (bulk wave); behavior not yet reviewed
# func 4620..462E  len 000F B  evidence: seed+reko
# calls: L_0053eb
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_4620:
L_004820:
        mov    $0x0,%bh
L_004822:
        mov    $0x20,%bl
L_004824:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
L_004826:
        mov    $0x0,%bh
L_004828:
        mov    $0x4,%bl
L_00482a:
        .byte 0x8b,0xf3  # forced-kept: gas re-encodes 'mov    %bx,%si' differently
L_00482c:
        call L_0053eb
