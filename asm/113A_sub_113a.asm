# sub_113a — mechanical clean (bulk wave); behavior not yet reviewed
# func 113A..1140  len 0007 B  evidence: seed+call+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_113a:
L_00133a:
        mov    0x4a,%al
L_00133d:
        .byte 0x0a,0xc0  # forced-kept: gas re-encodes 'or     %al,%al' differently
L_00133f:
        jne L_001342
