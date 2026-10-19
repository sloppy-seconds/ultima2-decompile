# sub_42e2 — mechanical clean (bulk wave); behavior not yet reviewed
# func 42E2..42F0  len 000F B  evidence: seed+reko
# calls: L_000c33
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_42e2:
L_0044e2:
        clc
L_0044e3:
        mov    0x51,%al
L_0044e6:
        adc    0x1f,%al
L_0044ea:
        daa
L_0044eb:
        mov    %al,0x51
L_0044ee:
        jmp L_000c33
