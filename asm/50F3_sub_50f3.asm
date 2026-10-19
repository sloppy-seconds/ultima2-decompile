# sub_50f3 — mechanical clean (bulk wave); behavior not yet reviewed
# func 50F3..50F8  len 0006 B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_50f3:
L_0052f3:
        xor    $0xff,%al
L_0052f5:
        clc
L_0052f6:
        adc    $0x1,%al
L_0052f8:
        ret
