# sub_7276 — mechanical clean (bulk wave); behavior not yet reviewed
# func 7276..7288  len 0013 B  evidence: call+reko
# calls: L_005eb2
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_7276:
L_007476:
        nop
L_007477:
        cmpb   $0xff,%cs:0x6998
L_00747d:
        jne L_007488
L_00747f:
        call L_005eb2
L_007482:
        movb   $0x0,%cs:0x6998
L_007488:
        ret
