# sub_5ef2 — mechanical clean (bulk wave); behavior not yet reviewed
# func 5EF2..5F07  len 0016 B  evidence: seed+call+reko
# calls: L_005fa9
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_5ef2:
L_0060f2:
        push   %ax
L_0060f3:
        push   %bx
L_0060f4:
        push   %cx
L_0060f5:
        push   %dx
L_0060f6:
        mov    $0x800,%ax
L_0060f9:
        mov    $0x1800,%bx
L_0060fc:
        mov    $0x47,%cx
L_0060ff:
        mov    $0x800,%dx
L_006102:
        mov    $0x8,%bp
L_006105:
        call L_005fa9
