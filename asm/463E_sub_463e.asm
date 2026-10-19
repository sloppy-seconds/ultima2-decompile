# sub_463e — mechanical clean (bulk wave); behavior not yet reviewed
# func 463E..464A  len 000D B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_463e:
L_00483e:
        mov    $0x0,%bh
L_004840:
        mov    $0x4,%bl
L_004842:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
L_004844:
        mov    $0x0,%bh
L_004846:
        mov    $0x5,%bl
L_004848:
        .byte 0x8b,0xf3  # forced-kept: gas re-encodes 'mov    %bx,%si' differently
L_00484a:
        .byte 0xe8  # forced-kept: stop-trunc call   0x53eb
