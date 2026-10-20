# sub_4b35 — mechanical clean (bulk wave); behavior not yet reviewed
# func 4B35..4B4D  len 0019 B  evidence: call+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_4b35:
L_004d35:
        push   %bx
L_004d36:
        push   %es
L_004d37:
        mov    %ax,%es
L_004d39:
        mov    $0xffff,%ax
L_004d3c:
        mov    $0x0,%bx
L_004d3f:
        xor    %ax,%es:(%bx)
L_004d42:
        add    $0x2,%bx
L_004d45:
        cmp    $0x1900,%bx
L_004d49:
        jne L_004d3f
L_004d4b:
        pop    %es
L_004d4c:
        pop    %bx
L_004d4d:
        ret
