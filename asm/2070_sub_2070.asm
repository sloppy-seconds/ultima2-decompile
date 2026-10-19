# sub_2070 — mechanical clean (bulk wave); behavior not yet reviewed
# func 2070..20A3  len 0034 B  evidence: seed+reko
# strings: "YOU DONT HAVE THAT MUCH!"
# calls: L_0051df (str_out)
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_2070:
L_002270:
        clc
L_002271:
        mov    0x59,%al
L_002274:
        adc    0x28,%al
L_002278:
        daa
L_002279:
        mov    %al,0x59
L_00227c:
        mov    0x58,%al
L_00227f:
        adc    0x27,%al
L_002283:
        daa
L_002284:
        mov    %al,0x58
L_002287:
        pop    %ax
L_002288:
        call L_0051df
        db "YOU DONT HAVE THAT MUCH!",0x00        # string
