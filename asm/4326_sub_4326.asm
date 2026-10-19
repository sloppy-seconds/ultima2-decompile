# sub_4326 — mechanical clean (bulk wave); behavior not yet reviewed
# func 4326..4339  len 0014 B  evidence: seed+reko
# calls: L_0052b3
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_4326:
L_004526:
        mov    0x1,%al
L_004529:
        mov    %al,0x24
L_00452c:
        mov    0x0,%al
L_00452f:
        clc
L_004530:
        adc    0x19,%al
L_004534:
        mov    %al,0x23
L_004537:
        call L_0052b3
