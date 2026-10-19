# sub_5fe0 — mechanical clean (bulk wave); behavior not yet reviewed
# func 5FE0..5FF6  len 0017 B  evidence: seed+call+reko
# calls: L_005fa9
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_5fe0:
L_0061e0:
        push   %ax
L_0061e1:
        push   %bx
L_0061e2:
        push   %cx
L_0061e3:
        push   %dx
L_0061e4:
        push   %bp
L_0061e5:
        mov    $0x400,%ax
L_0061e8:
        mov    $0x1000,%bx
L_0061eb:
        mov    $0x1,%cx
L_0061ee:
        mov    $0x200,%dx
L_0061f1:
        mov    $0x80,%bp
L_0061f4:
        call L_005fa9
