# sub_33f8 — mechanical clean (bulk wave); behavior not yet reviewed
# func 33F8..33FD  len 0006 B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_33f8:
L_0035f8:
        cmc
L_0035f9:
        sbb    $0x1,%al
L_0035fb:
        cmc
L_0035fc:
        jne L_003601
