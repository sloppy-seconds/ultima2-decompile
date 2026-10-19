# sub_2cb5 — mechanical clean (bulk wave); behavior not yet reviewed
# func 2CB5..2CCC  len 0018 B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_2cb5:
L_002eb5:
        mov    $0x0,%bh
L_002eb7:
        mov    $0x0,%bl
L_002eb9:
        .byte 0x8b,0xf3  # forced-kept: gas re-encodes 'mov    %bx,%si' differently
L_002ebb:
        mov    0x1b7(%di),%al
L_002ebf:
        mov    0x6,%bx
L_002ec3:
        mov    %al,(%bx,%si)
L_002ec5:
        mov    0x197(%di),%al
L_002ec9:
        cmp    $0x40,%al
L_002ecb:
        jne L_002ed3
