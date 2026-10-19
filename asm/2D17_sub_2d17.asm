# sub_2d17 — mechanical clean (bulk wave); behavior not yet reviewed
# func 2D17..2D21  len 000B B  evidence: seed+reko
# calls: L_002f8c
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_2d17:
L_002f17:
        mov    $0x0,%bh
L_002f19:
        mov    0x1f,%bl
L_002f1d:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
L_002f1f:
        jmp L_002f8c
L_002f21:
        nop
