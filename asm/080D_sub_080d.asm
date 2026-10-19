# sub_080d — mechanical clean (bulk wave); behavior not yet reviewed
# func 080D..0838  len 002C B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_080d:
L_000a0d:
        mov    0x47,%al
L_000a10:
        .byte 0x02,0xc0  # forced-kept: gas re-encodes 'add    %al,%al' differently
L_000a12:
        clc
L_000a13:
        adc    $0x78,%al
L_000a15:
        mov    %al,0x13
L_000a18:
        mov    $0x0,%al
L_000a1a:
        mov    %al,0x26a
L_000a1d:
        mov    %al,0x26b
L_000a20:
        mov    %al,0x26c
L_000a23:
        mov    %al,0x26d
L_000a26:
        mov    0x5a,%al
L_000a29:
        mov    %al,0x0
L_000a2c:
        mov    0x5b,%al
L_000a2f:
        mov    %al,0x1
L_000a32:
        mov    0x69,%al
L_000a35:
        .byte 0x0a,0xc0  # forced-kept: gas re-encodes 'or     %al,%al' differently
L_000a37:
        je L_000a50
