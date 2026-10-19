# sub_5ae1 — mechanical clean (bulk wave); behavior not yet reviewed
# func 5AE1..5AEC  len 000C B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_5ae1:
L_005ce1:
        clc
L_005ce2:
        mov    0x4,%al
L_005ce5:
        adc    0x2,%al
L_005ce9:
        cmp    $0x40,%al
L_005ceb:
        jae L_005cf9
