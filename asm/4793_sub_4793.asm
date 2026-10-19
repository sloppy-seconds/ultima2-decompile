# sub_4793 — mechanical clean (bulk wave); behavior not yet reviewed
# func 4793..47A1  len 000F B  evidence: seed+reko
# calls: L_0053eb
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_4793:
L_004993:
        mov    $0x0,%bh
L_004995:
        mov    $0x1,%bl
L_004997:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
L_004999:
        mov    $0x0,%bh
L_00499b:
        mov    $0xc,%bl
L_00499d:
        .byte 0x8b,0xf3  # forced-kept: gas re-encodes 'mov    %bx,%si' differently
L_00499f:
        call L_0053eb
