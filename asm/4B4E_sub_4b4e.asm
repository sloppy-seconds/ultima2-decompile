# sub_4b4e — mechanical clean (bulk wave); behavior not yet reviewed
# func 4B4E..4B5C  len 000F B  evidence: call+reko
# calls: L_004d5d
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_4b4e:
L_004d4e:
        push   %ax
L_004d4f:
        mov    $0xb800,%ax
L_004d52:
        call L_004d5d
L_004d55:
        mov    $0xba00,%ax
L_004d58:
        call L_004d5d
L_004d5b:
        pop    %ax
L_004d5c:
        ret
