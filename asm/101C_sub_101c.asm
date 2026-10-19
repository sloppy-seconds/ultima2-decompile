# sub_101c — mechanical clean (bulk wave); behavior not yet reviewed
# func 101C..102A  len 000F B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_101c:
L_00121c:
        nop
L_00121d:
        .byte 0x8b,0xdf  # forced-kept: gas re-encodes 'mov    %di,%bx' differently
L_00121f:
        mov    %bl,0x25
L_001223:
        mov    0x197(%di),%al
L_001227:
        .byte 0x0a,0xc0  # forced-kept: gas re-encodes 'or     %al,%al' differently
L_001229:
        je L_001240
