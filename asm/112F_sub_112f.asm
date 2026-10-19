# sub_112f — mechanical clean (bulk wave); behavior not yet reviewed
# func 112F..1139  len 000B B  evidence: seed+reko
# calls: L_002401
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_112f:
L_00132f:
        mov    $0x0,%bh
L_001331:
        mov    0x25,%bl
L_001335:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
L_001337:
        jmp L_002401
