# sub_5379 — mechanical clean (bulk wave); behavior not yet reviewed
# func 5379..538E  len 0016 B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_5379:
L_005579:
        pop    %es
L_00557a:
        pop    %di
L_00557b:
        pop    %si
L_00557c:
        pop    %dx
L_00557d:
        pop    %cx
L_00557e:
        pop    %ax
L_00557f:
        ret
L_005580:
        push   %ax
L_005581:
        push   %bx
L_005582:
        mov    $0x100,%bx
L_005585:
        dec    %bx
L_005586:
        jne L_005585
L_005588:
        dec    %al
L_00558a:
        jne L_005582
L_00558c:
        pop    %bx
L_00558d:
        pop    %ax
L_00558e:
        ret
