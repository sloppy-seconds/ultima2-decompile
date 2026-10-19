# sub_243e — mechanical clean (bulk wave); behavior not yet reviewed
# func 243E..2452  len 0015 B  evidence: seed+reko
# calls: L_002490
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_243e:
L_00263e:
        nop
L_00263f:
        mov    0x5a,%al
L_002642:
        mov    %al,0x0
L_002645:
        mov    0x5b,%al
L_002648:
        mov    %al,0x1
L_00264b:
        mov    $0x0,%al
L_00264d:
        mov    %al,0x4a
L_002650:
        call L_002490
