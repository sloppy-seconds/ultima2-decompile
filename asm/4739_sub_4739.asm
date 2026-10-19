# sub_4739 — mechanical clean (bulk wave); behavior not yet reviewed
# func 4739..4747  len 000F B  evidence: seed+reko
# calls: L_0053eb
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_4739:
L_004939:
        mov    $0x0,%bh
L_00493b:
        mov    $0x1,%bl
L_00493d:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
L_00493f:
        mov    $0x0,%bh
L_004941:
        mov    $0x9,%bl
L_004943:
        .byte 0x8b,0xf3  # forced-kept: gas re-encodes 'mov    %bx,%si' differently
L_004945:
        call L_0053eb
