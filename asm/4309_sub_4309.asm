# sub_4309 — mechanical clean (bulk wave); behavior not yet reviewed
# func 4309..430F  len 0007 B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_4309:
L_004509:
        mov    0x19,%al
L_00450c:
        .byte 0x0a,0xc0  # forced-kept: gas re-encodes 'or     %al,%al' differently
L_00450e:
        jne L_004526
