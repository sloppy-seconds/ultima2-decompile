# sub_45b1 — mechanical clean (bulk wave); behavior not yet reviewed
# func 45B1..45B9  len 0009 B  evidence: seed+reko
# calls: L_00528c
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_45b1:
L_0047b1:
        mov    0x47,%al
L_0047b4:
        clc
L_0047b5:
        adc    $0x48,%al
L_0047b7:
        call L_00528c
