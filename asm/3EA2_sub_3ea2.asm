# sub_3ea2 — mechanical clean (bulk wave); behavior not yet reviewed
# func 3EA2..3EAA  len 0009 B  evidence: seed+reko
# calls: L_00528c
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_3ea2:
L_0040a2:
        mov    %al,0x1f
L_0040a5:
        clc
L_0040a6:
        adc    $0x13,%al
L_0040a8:
        call L_00528c
