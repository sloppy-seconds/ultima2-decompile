# sub_0767 — mechanical clean (bulk wave); behavior not yet reviewed
# func 0767..0775  len 000F B  evidence: seed+reko
# calls: L_0053eb
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_0767:
L_000967:
        mov    $0x0,%bh
L_000969:
        mov    $0xc,%bl
L_00096b:
        .byte 0x8b,0xf3  # forced-kept: gas re-encodes 'mov    %bx,%si' differently
L_00096d:
        mov    $0x0,%bh
L_00096f:
        mov    $0xa,%bl
L_000971:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
L_000973:
        call L_0053eb
