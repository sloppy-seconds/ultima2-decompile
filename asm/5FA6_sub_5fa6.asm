# sub_5fa6 — mechanical clean (bulk wave); behavior not yet reviewed
# func 5FA6..5FBC  len 0017 B  evidence: seed+call+reko
# calls: L_005fa9
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_5fa6:
L_0061a6:
        push   %ax
L_0061a7:
        push   %bx
L_0061a8:
        push   %cx
L_0061a9:
        push   %dx
L_0061aa:
        push   %bp
L_0061ab:
        mov    $0x2f8,%ax
L_0061ae:
        mov    $0x320,%bx
L_0061b1:
        mov    $0xffff,%cx
L_0061b4:
        mov    $0x50,%dx
L_0061b7:
        mov    $0xf00,%bp
L_0061ba:
        call L_005fa9
