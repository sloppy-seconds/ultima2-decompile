# sub_07aa — mechanical clean (bulk wave); behavior not yet reviewed
# func 07AA..07B0  len 0007 B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_07aa:
L_0009aa:
        mov    0x36,%al
L_0009ad:
        .byte 0x0a,0xc0  # forced-kept: gas re-encodes 'or     %al,%al' differently
L_0009af:
        jne L_0009e6
