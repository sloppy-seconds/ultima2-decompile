# sub_10ce — mechanical clean (bulk wave); behavior not yet reviewed
# func 10CE..10E8  len 001B B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_10ce:
L_0012ce:
        nop
L_0012cf:
        mov    $0x0,%bh
L_0012d1:
        mov    0x25,%bl
L_0012d5:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
L_0012d7:
        clc
L_0012d8:
        mov    0x137(%di),%al
L_0012dc:
        adc    0x19,%al
L_0012e0:
        and    $0x3f,%al
L_0012e2:
        mov    %al,0x23
L_0012e5:
        cmp    $0x4,%al
L_0012e7:
        jae L_0012ec
