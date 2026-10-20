# sub_4232 — mechanical clean (bulk wave); behavior not yet reviewed
# func 4232..4245  len 0014 B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_4232:
L_004432:
        mov    0x4a,%al
L_004435:
        cmp    $0x3,%al
L_004437:
        jne L_004446
L_004439:
        mov    0x1d7(%di),%al
L_00443d:
        cmp    $0x81,%al
L_00443f:
        jne L_004446
L_004441:
        mov    $0x1,%al
L_004443:
        mov    %al,0x6c
