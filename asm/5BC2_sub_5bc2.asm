# sub_5bc2 — mechanical clean (bulk wave); behavior not yet reviewed
# func 5BC2..5C10  len 004F B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_5bc2:
L_005dc2:
        clc
L_005dc3:
        mov    0x4,%al
L_005dc6:
        adc    0x2,%al
L_005dca:
        and    $0x3f,%al
L_005dcc:
        mov    %al,%cs:0x5ab0
L_005dd0:
        clc
L_005dd1:
        mov    0x5,%al
L_005dd4:
        adc    0x3,%al
L_005dd8:
        and    $0x3f,%al
L_005dda:
        mov    %al,0x7
L_005ddd:
        mov    $0x0,%al
L_005ddf:
        clc
L_005de0:
        rcrb   $1,0x7
L_005de4:
        rcr    $1,%al
L_005de6:
        clc
L_005de7:
        rcrb   $1,0x7
L_005deb:
        rcr    $1,%al
L_005ded:
        adc    %cs:0x5ab0,%al
L_005df2:
        mov    %al,0x6
L_005df5:
        clc
L_005df6:
        mov    0x7,%al
L_005df9:
        adc    0x473,%al
L_005dfd:
        mov    %al,0x7
L_005e00:
        mov    0x6,%bx
L_005e04:
        mov    (%bx,%si),%al
L_005e06:
        clc
L_005e07:
        rcr    $1,%al
L_005e09:
        and    $0xfe,%al
L_005e0b:
        cmp    0x372(%di),%al
L_005e0f:
        jne L_005e25
