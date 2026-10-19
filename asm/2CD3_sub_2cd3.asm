# sub_2cd3 — mechanical clean (bulk wave); behavior not yet reviewed
# func 2CD3..2CD7  len 0005 B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_2cd3:
L_002ed3:
        nop
L_002ed4:
        cmp    $0x60,%al
L_002ed6:
        jne L_002ee5
