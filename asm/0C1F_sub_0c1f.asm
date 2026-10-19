# sub_0c1f — mechanical clean (bulk wave); behavior not yet reviewed
# func 0C1F..0C2A  len 000C B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_0c1f:
L_000e1f:
        mov    $0x4,%al
L_000e21:
        mov    %al,0x12
L_000e24:
        mov    0x4a,%al
L_000e27:
        .byte 0x0a,0xc0  # forced-kept: gas re-encodes 'or     %al,%al' differently
L_000e29:
        jne L_000e33
