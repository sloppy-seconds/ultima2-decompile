# sub_53a0 — mechanical clean (bulk wave); behavior not yet reviewed
# func 53A0..53B4  len 0015 B  evidence: call+reko
# calls: L_005203
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_53a0:
L_0055a0:
        push   %ax
L_0055a1:
        push   %cx
L_0055a2:
        movb   $0x0,0x2e
L_0055a7:
        mov    $0x20,%al
L_0055a9:
        mov    $0x28,%cx
L_0055ac:
        call L_005203
L_0055af:
        dec    %cx
L_0055b0:
        jne L_0055ac
L_0055b2:
        pop    %cx
L_0055b3:
        pop    %ax
L_0055b4:
        ret
