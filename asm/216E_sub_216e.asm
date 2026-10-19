# sub_216e — mechanical clean (bulk wave); behavior not yet reviewed
# func 216E..2185  len 0018 B  evidence: seed+reko
# calls: L_0052b3
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_216e:
L_00236e:
        clc
L_00236f:
        mov    0x137(%di),%al
L_002373:
        adc    0x19,%al
L_002377:
        and    $0x3f,%al
L_002379:
        mov    %al,0x23
L_00237c:
        mov    0x157(%di),%al
L_002380:
        mov    %al,0x24
L_002383:
        call L_0052b3
