# sub_51fd — mechanical clean (bulk wave); behavior not yet reviewed
# func 51FD..5211  len 0015 B  evidence: seed+call+reko
# seams: video_int10
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_51fd:
L_0053fd:
        push   %ax
L_0053fe:
        push   %bx
L_0053ff:
        push   %cx
L_005400:
        push   %dx
L_005401:
        mov    0x2f,%dh
L_005405:
        mov    0x2e,%dl
L_005409:
        mov    $0x1,%cx
L_00540c:
        mov    $0x0,%bh
L_00540e:
        mov    $0x2,%ah
L_005410:
video_int10:
        int $0x10    # video_int10 seam
