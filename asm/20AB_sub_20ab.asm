# sub_20ab — mechanical clean (bulk wave); behavior not yet reviewed
# func 20AB..20CE  len 0024 B  evidence: seed+call+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_20ab:
L_0022ab:
        nop
L_0022ac:
        clc
L_0022ad:
        adc    $0x8,%al
L_0022af:
        mov    %al,0x20
L_0022b2:
        mov    $0x0,%al
L_0022b4:
        mov    %al,0x27
L_0022b7:
        mov    %al,0x29
L_0022ba:
        mov    $0x4,%al
L_0022bc:
        mov    %al,0x28
L_0022bf:
        mov    %al,0x2a
L_0022c2:
        mov    0x50,%al
L_0022c5:
        adc    0x4e,%al
L_0022c9:
        mov    $0x0,%bh
L_0022cb:
        mov    $0x0,%bl
L_0022cd:
        .byte 0x8b,0xf3  # forced-kept: gas re-encodes 'mov    %bx,%si' differently
