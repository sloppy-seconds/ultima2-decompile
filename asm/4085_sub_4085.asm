# sub_4085 — mechanical clean (bulk wave); behavior not yet reviewed
# func 4085..409E  len 001A B  evidence: seed+reko
# calls: L_0052b3
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_4085:
L_004285:
        nop
L_004286:
        clc
L_004287:
        mov    0x23,%al
L_00428a:
        adc    0x19,%al
L_00428e:
        mov    %al,0x23
L_004291:
        clc
L_004292:
        mov    0x24,%al
L_004295:
        adc    0x1a,%al
L_004299:
        mov    %al,0x24
L_00429c:
        call L_0052b3
