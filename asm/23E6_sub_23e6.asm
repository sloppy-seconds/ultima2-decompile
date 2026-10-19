# sub_23e6 — mechanical clean (bulk wave); behavior not yet reviewed
# func 23E6..2401  len 001C B  evidence: seed+call+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_23e6:
L_0025e6:
        clc
L_0025e7:
        mov    0x0,%al
L_0025ea:
        adc    0x19,%al
L_0025ee:
        mov    %al,0x23
L_0025f1:
        clc
L_0025f2:
        mov    0x1,%al
L_0025f5:
        adc    0x1a,%al
L_0025f9:
        mov    %al,0x24
L_0025fc:
        mov    $0x0,%bh
L_0025fe:
        mov    $0x1f,%bl
L_002600:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
