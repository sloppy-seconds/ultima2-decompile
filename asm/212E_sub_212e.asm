# sub_212e — mechanical clean (bulk wave); behavior not yet reviewed
# func 212E..214C  len 001F B  evidence: seed+reko
# calls: L_0052b3
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_212e:
L_00232e:
        clc
L_00232f:
        mov    0x137(%di),%al
L_002333:
        adc    0x19,%al
L_002337:
        and    $0x3f,%al
L_002339:
        mov    %al,0x23
L_00233c:
        clc
L_00233d:
        mov    0x157(%di),%al
L_002341:
        adc    0x1a,%al
L_002345:
        and    $0x3f,%al
L_002347:
        mov    %al,0x24
L_00234a:
        call L_0052b3
