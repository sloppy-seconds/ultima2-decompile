# sub_0bdb — mechanical clean (bulk wave); behavior not yet reviewed
# func 0BDB..0C01  len 0027 B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_0bdb:
L_000ddb:
        and    0x22,%al
L_000ddf:
        and    $0x77,%al
L_000de1:
        clc
L_000de2:
        adc    $0x1,%al
L_000de4:
        mov    %al,0x22
L_000de7:
        stc
L_000de8:
        mov    0x52,%al
L_000deb:
        cmc
L_000dec:
        sbb    0x22,%al
L_000df0:
        das
L_000df1:
        cmc
L_000df2:
        mov    %al,0x52
L_000df5:
        mov    0x51,%al
L_000df8:
        cmc
L_000df9:
        sbb    $0x0,%al
L_000dfb:
        das
L_000dfc:
        cmc
L_000dfd:
        mov    %al,0x51
L_000e00:
        jae L_000e62
