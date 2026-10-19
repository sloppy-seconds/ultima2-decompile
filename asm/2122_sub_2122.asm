# sub_2122 — mechanical clean (bulk wave); behavior not yet reviewed
# func 2122..2129  len 0008 B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_2122:
L_002322:
        mov    0x177(%di),%al
L_002326:
        cmp    $0x10,%al
L_002328:
        jae L_00232e
