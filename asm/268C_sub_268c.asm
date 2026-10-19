# sub_268c — mechanical clean (bulk wave); behavior not yet reviewed
# func 268C..269E  len 0013 B  evidence: seed+reko
# calls: L_005cb1
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_268c:
L_00288c:
        mov    0x70,%al
L_00288f:
        mov    0x6,%bx
L_002893:
        mov    %al,(%bx,%si)
L_002895:
        clc
L_002896:
        clc
L_002897:
        rcr    $1,%al
L_002899:
        mov    %al,0x13
L_00289c:
        call L_005cb1
