# sub_031f — mechanical clean (bulk wave); behavior not yet reviewed
# func 031F..0349  len 002B B  evidence: reko
# strings: "'P' - PLAY A GAME OF ULTIMA ]["
# calls: L_0051df (str_out)
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_031f:
L_00051f:
        push   %es
L_000520:
        das
L_000521:
        add    %cl,(%bx)
L_000523:
        mov    $0x6,%al
L_000525:
        mov    %al,0x2e
L_000528:
        call L_0051df
        db "'P' - PLAY A GAME OF ULTIMA ][",0x00        # string
