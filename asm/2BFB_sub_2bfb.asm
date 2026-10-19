# sub_2bfb — mechanical clean (bulk wave); behavior not yet reviewed
# func 2BFB..2C18  len 001E B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_2bfb:
L_002dfb:
        mov    0x61,%al
L_002dfe:
        .byte 0x02,0xc0  # forced-kept: gas re-encodes 'add    %al,%al' differently
L_002e00:
        .byte 0x02,0xc0  # forced-kept: gas re-encodes 'add    %al,%al' differently
L_002e02:
        .byte 0x02,0xc0  # forced-kept: gas re-encodes 'add    %al,%al' differently
L_002e04:
        adc    0x4b,%al
L_002e08:
        clc
L_002e09:
        rcr    $1,%al
L_002e0b:
        clc
L_002e0c:
        rcr    $1,%al
L_002e0e:
        mov    %al,0x1f
L_002e11:
        mov    $0x0,%bh
L_002e13:
        mov    0x20,%bl
L_002e17:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
