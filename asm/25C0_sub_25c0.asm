# sub_25c0 — mechanical clean (bulk wave); behavior not yet reviewed
# func 25C0..25C8  len 0009 B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_25c0:
L_0027c0:
        mov    0x29,%al
L_0027c3:
        and    $0x7f,%al
L_0027c5:
        cmp    $0x60,%al
L_0027c7:
        jne L_0027cc
