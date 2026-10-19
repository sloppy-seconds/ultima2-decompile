# sub_4b1b — mechanical clean (bulk wave); behavior not yet reviewed
# func 4B1B..4B25  len 000B B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_4b1b:
L_004d1b:
        mov    %bx,0x2(%si)
L_004d1e:
        mov    %cx,0x4(%si)
L_004d21:
        pop    %dx
L_004d22:
        pop    %cx
L_004d23:
        pop    %bx
L_004d24:
        pop    %ax
L_004d25:
        ret
