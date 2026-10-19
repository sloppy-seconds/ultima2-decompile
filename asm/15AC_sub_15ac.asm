# sub_15ac — mechanical clean (bulk wave); behavior not yet reviewed
# func 15AC..15B3  len 0008 B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_15ac:
L_0017ac:
        nop
L_0017ad:
        mov    0x4a,%al
L_0017b0:
        cmp    $0x2,%al
L_0017b2:
        jne L_0017b7
