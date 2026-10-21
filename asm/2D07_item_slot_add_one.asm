# sub_2d07 — mechanical clean (bulk wave); behavior not yet reviewed
# func 2D07..2D16  len 0010 B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_2d07:
L_002f07:
        mov    $0x0,%ah
L_002f09:
        .byte 0x8b,0xf8  # forced-kept: gas re-encodes 'mov    %ax,%di' differently
L_002f0b:
        clc
L_002f0c:
        mov    0xd6(%di),%al
L_002f10:
        adc    $0x1,%al
L_002f12:
        daa
L_002f13:
        mov    %al,0xd6(%di)
