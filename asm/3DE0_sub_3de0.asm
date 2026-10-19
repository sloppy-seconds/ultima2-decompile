# sub_3de0 — mechanical clean (bulk wave); behavior not yet reviewed
# func 3DE0..3DE3  len 0004 B  evidence: reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_3de0:
L_003fe0:
        .byte 0x0a,0xc0  # forced-kept: gas re-encodes 'or     %al,%al' differently
L_003fe2:
        je L_003ffa
