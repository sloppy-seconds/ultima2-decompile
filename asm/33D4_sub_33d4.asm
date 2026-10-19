# sub_33d4 — mechanical clean (bulk wave); behavior not yet reviewed
# func 33D4..33D9  len 0006 B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_33d4:
L_0035d4:
        cmc
L_0035d5:
        sbb    $0x1,%al
L_0035d7:
        cmc
L_0035d8:
        jne L_0035dd
