# sub_33ef — mechanical clean (bulk wave); behavior not yet reviewed
# func 33EF..33F4  len 0006 B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_33ef:
L_0035ef:
        cmc
L_0035f0:
        sbb    $0x1,%al
L_0035f2:
        cmc
L_0035f3:
        jne L_0035f8
