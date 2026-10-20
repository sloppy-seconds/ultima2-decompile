# sub_5fc3 — mechanical clean (bulk wave); behavior not yet reviewed
# func 5FC3..5FDF  len 001D B  evidence: call
# calls: L_005fa9
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_5fc3:
L_0061c3:
        push   %ax
L_0061c4:
        push   %bx
L_0061c5:
        push   %cx
L_0061c6:
        push   %dx
L_0061c7:
        push   %bp
L_0061c8:
        mov    $0x492,%ax
L_0061cb:
        mov    $0x4c0,%bx
L_0061ce:
        mov    $0xffff,%cx
L_0061d1:
        mov    $0x5c,%dx
L_0061d4:
        mov    $0xb00,%bp
L_0061d7:
        call L_005fa9
L_0061da:
        pop    %bp
L_0061db:
        pop    %dx
L_0061dc:
        pop    %cx
L_0061dd:
        pop    %bx
L_0061de:
        pop    %ax
L_0061df:
        ret
