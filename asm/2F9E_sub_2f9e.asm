# sub_2f9e — mechanical clean (bulk wave); behavior not yet reviewed
# func 2F9E..2FAC  len 000F B  evidence: seed+reko
# calls: L_0052b3
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_2f9e:
L_00319e:
        mov    0x0,%al
L_0031a1:
        mov    %al,0x23
L_0031a4:
        mov    0x1,%al
L_0031a7:
        mov    %al,0x24
L_0031aa:
        call L_0052b3
