# sub_33c3 — mechanical clean (bulk wave); behavior not yet reviewed
# func 33C3..33D0  len 000E B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_33c3:
L_0035c3:
        nop
L_0035c4:
        mov    0x14,%al
L_0035c7:
        clc
L_0035c8:
        rcr    $1,%al
L_0035ca:
        stc
L_0035cb:
        cmc
L_0035cc:
        sbb    $0x5,%al
L_0035ce:
        cmc
L_0035cf:
        jne L_0035d4
