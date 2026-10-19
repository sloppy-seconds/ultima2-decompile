# sub_45a3 — mechanical clean (bulk wave); behavior not yet reviewed
# func 45A3..45AB  len 0009 B  evidence: seed+reko
# calls: L_00528c
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_45a3:
L_0047a3:
        mov    0x48,%al
L_0047a6:
        clc
L_0047a7:
        adc    $0x44,%al
L_0047a9:
        call L_00528c
