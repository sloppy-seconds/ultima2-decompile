# sub_5eac — mechanical clean (bulk wave); behavior not yet reviewed
# func 5EAC..5EC1  len 0016 B  evidence: seed+call+reko
# calls: L_005fa9
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_5eac:
L_0060ac:
        push   %ax
L_0060ad:
        push   %bx
L_0060ae:
        push   %cx
L_0060af:
        push   %dx
L_0060b0:
        mov    $0x300,%ax
L_0060b3:
        mov    $0x1000,%bx
L_0060b6:
        mov    $0x2,%cx
L_0060b9:
        mov    $0x200,%dx
L_0060bc:
        mov    $0x8,%bp
L_0060bf:
        call L_005fa9
