# sub_4b5d — mechanical clean (bulk wave); behavior not yet reviewed
# func 4B5D..4B75  len 0019 B  evidence: call+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_4b5d:
L_004d5d:
        push   %bx
L_004d5e:
        push   %es
L_004d5f:
        mov    %ax,%es
L_004d61:
        mov    $0x0,%ax
L_004d64:
        mov    $0x0,%bx
L_004d67:
        mov    %ax,%es:(%bx)
L_004d6a:
        add    $0x2,%bx
L_004d6d:
        cmp    $0x1900,%bx
L_004d71:
        jne L_004d67
L_004d73:
        pop    %es
L_004d74:
        pop    %bx
L_004d75:
        ret
