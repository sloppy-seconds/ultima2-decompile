# sub_522b — mechanical clean (bulk wave); behavior not yet reviewed
# func 522B..5235  len 000B B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_522b:
L_00542b:
        mov    0x23f(%bx),%al
L_00542f:
        mov    %al,0x240(%bx)
L_005433:
        dec    %bx
L_005434:
        jns L_00542b
