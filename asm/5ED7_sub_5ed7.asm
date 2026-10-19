# sub_5ed7 — mechanical clean (bulk wave); behavior not yet reviewed
# func 5ED7..5EEC  len 0016 B  evidence: seed+call+reko
# calls: L_005fa9
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_5ed7:
L_0060d7:
        push   %ax
L_0060d8:
        push   %bx
L_0060d9:
        push   %cx
L_0060da:
        push   %dx
L_0060db:
        mov    $0x200,%ax
L_0060de:
        mov    $0x3000,%bx
L_0060e1:
        mov    $0x20,%cx
L_0060e4:
        mov    $0xe00,%dx
L_0060e7:
        mov    $0x8,%bp
L_0060ea:
        call L_005fa9
