# sub_5aff — mechanical clean (bulk wave); behavior not yet reviewed
# func 5AFF..5B32  len 0034 B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_5aff:
L_005cff:
        mov    %al,0x7
L_005d02:
        mov    $0x0,%al
L_005d04:
        clc
L_005d05:
        rcrb   $1,0x7
L_005d09:
        rcr    $1,%al
L_005d0b:
        clc
L_005d0c:
        rcrb   $1,0x7
L_005d10:
        rcr    $1,%al
L_005d12:
        adc    0x4,%al
L_005d16:
        adc    0x2,%al
L_005d1a:
        mov    %al,0x6
L_005d1d:
        clc
L_005d1e:
        mov    0x7,%al
L_005d21:
        adc    0x473,%al
L_005d25:
        mov    %al,0x7
L_005d28:
        mov    0x6,%bx
L_005d2c:
        mov    (%bx,%si),%al
L_005d2e:
        clc
L_005d2f:
        rcr    $1,%al
L_005d31:
        and    $0xfe,%al
