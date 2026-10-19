# sub_5343 — mechanical clean (bulk wave); behavior not yet reviewed
# func 5343..5350  len 000E B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_5343:
L_005543:
        mov    %cs:0x4f07,%dx
L_005548:
        push   %ds
L_005549:
        cmpw   $0x4950,0x246
L_00554f:
        jne L_005556
