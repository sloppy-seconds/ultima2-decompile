# sub_3be0 — mechanical clean (bulk wave); behavior not yet reviewed
# func 3BE0..3BE3  len 0004 B  evidence: reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_3be0:
L_003de0:
        .byte 0x0a,0xc0  # forced-kept: gas re-encodes 'or     %al,%al' differently
L_003de2:
        jne L_003e04
