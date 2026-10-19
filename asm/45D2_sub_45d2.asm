# sub_45d2 — mechanical clean (bulk wave); behavior not yet reviewed
# func 45D2..45D9  len 0008 B  evidence: reko
# calls: L_00528c
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_45d2:
L_0047d2:
        popa
L_0047d3:
        add    %bh,%al
L_0047d5:
        adc    $0x13,%al
L_0047d7:
        call L_00528c
