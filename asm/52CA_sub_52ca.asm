# sub_52ca — mechanical clean (bulk wave); behavior not yet reviewed
# func 52CA..52E6  len 001D B  evidence: seed+call+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_52ca:
L_0054ca:
        pop    %bx
L_0054cb:
        add    $0x8,%bx
L_0054ce:
        push   %bx
L_0054cf:
        push   %ax
L_0054d0:
        push   %cx
L_0054d1:
        push   %dx
L_0054d2:
        push   %si
L_0054d3:
        push   %di
L_0054d4:
        push   %es
L_0054d5:
        mov    %ah,%cs:0x4f04
L_0054da:
        mov    %cx,%cs:0x4f05
L_0054df:
        mov    %dx,%cs:0x4f07
L_0054e4:
        mov    $0x24,%si
