# sub_02cc — mechanical clean (bulk wave); behavior not yet reviewed
# func 02CC..02E2  len 0017 B  evidence: reko
# strings: "AND ORIGIN"
# calls: L_0051df (str_out)
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_02cc:
L_0004cc:
        push   %es
L_0004cd:
        das
L_0004ce:
        add    %dl,(%bx)
L_0004d0:
        mov    $0xf,%al
L_0004d2:
        mov    %al,0x2e
L_0004d5:
        call L_0051df
        db "AND ORIGIN",0x00        # string
