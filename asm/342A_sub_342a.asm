# sub_342a — mechanical clean (bulk wave); behavior not yet reviewed
# func 342A..343B  len 0012 B  evidence: seed+reko
# calls: L_002490
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_342a:
L_00362a:
        mov    $0x1f,%al
L_00362c:
        mov    %al,0x0
L_00362f:
        mov    $0x3e,%al
L_003631:
        mov    %al,0x1
L_003634:
        mov    $0x1,%al
L_003636:
        mov    %al,0x4a
L_003639:
        call L_002490
