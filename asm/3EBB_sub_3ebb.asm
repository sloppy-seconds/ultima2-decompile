# sub_3ebb — mechanical clean (bulk wave); behavior not yet reviewed
# func 3EBB..3EC1  len 0007 B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_3ebb:
L_0040bb:
        mov    0x1f,%al
L_0040be:
        .byte 0x0a,0xc0  # forced-kept: gas re-encodes 'or     %al,%al' differently
L_0040c0:
        je L_0040d4
