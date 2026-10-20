# timed_wait — delay loop (called with AH=28h, CX=0x4000, DX=0 by cmd_C)
# name-evidence: cmd_C call-site evidence + loop over CX; already annotated in cmd_C
# func 52CA..52E6  len 001D B  evidence: seed+call+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
timed_wait:
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
