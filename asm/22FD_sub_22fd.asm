# sub_22fd — mechanical clean (bulk wave); behavior not yet reviewed
# func 22FD..2303  len 0007 B  evidence: seed+call+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_22fd:
L_0024fd:
        mov    0x6d,%al
L_002500:
        .byte 0x0a,0xc0  # forced-kept: gas re-encodes 'or     %al,%al' differently
L_002502:
        je L_002505
