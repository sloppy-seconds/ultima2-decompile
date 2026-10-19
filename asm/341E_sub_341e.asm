# sub_341e — mechanical clean (bulk wave); behavior not yet reviewed
# func 341E..3429  len 000C B  evidence: reko
# calls: L_0024fd
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_341e:
L_00361e:
        mov    %al,0x5a
L_003621:
        mov    0x1,%al
L_003624:
        mov    %al,0x5b
L_003627:
        call L_0024fd
