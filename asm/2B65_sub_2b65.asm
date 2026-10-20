# sub_2b65 — mechanical clean (bulk wave); behavior not yet reviewed
# func 2B65..2B8E  len 002A B  evidence: call+reko
# calls: L_004d76
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_2b65:
L_002d65:
        .byte 0x8b,0xdf  # forced-kept: gas re-encodes 'mov    %di,%bx' differently
L_002d67:
        mov    %bl,0x479
L_002d6b:
        .byte 0x8b,0xde  # forced-kept: gas re-encodes 'mov    %si,%bx' differently
L_002d6d:
        mov    %bl,0x47a
L_002d71:
        mov    0x19,%al
L_002d74:
        .byte 0x02,0xc0  # forced-kept: gas re-encodes 'add    %al,%al' differently
L_002d76:
        .byte 0x02,0xc0  # forced-kept: gas re-encodes 'add    %al,%al' differently
L_002d78:
        adc    0x479,%al
L_002d7c:
        mov    %al,0x479
L_002d7f:
        mov    0x1a,%al
L_002d82:
        .byte 0x02,0xc0  # forced-kept: gas re-encodes 'add    %al,%al' differently
L_002d84:
        adc    0x47a,%al
L_002d88:
        mov    %al,0x47a
L_002d8b:
        call L_004d76
L_002d8e:
        ret
