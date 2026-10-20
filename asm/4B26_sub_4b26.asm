# sub_4b26 — mechanical clean (bulk wave); behavior not yet reviewed
# func 4B26..4B34  len 000F B  evidence: call+reko
# calls: L_004d35
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_4b26:
L_004d26:
        push   %ax
L_004d27:
        mov    $0xb800,%ax
L_004d2a:
        call L_004d35
L_004d2d:
        mov    $0xba00,%ax
L_004d30:
        call L_004d35
L_004d33:
        pop    %ax
L_004d34:
        ret
