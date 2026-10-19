# sub_33dd — mechanical clean (bulk wave); behavior not yet reviewed
# func 33DD..33E2  len 0006 B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_33dd:
L_0035dd:
        cmc
L_0035de:
        sbb    $0x1,%al
L_0035e0:
        cmc
L_0035e1:
        jne L_0035e6
