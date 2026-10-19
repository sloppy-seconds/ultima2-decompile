# sub_0bd1 — mechanical clean (bulk wave); behavior not yet reviewed
# func 0BD1..0BD7  len 0007 B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_0bd1:
L_000dd1:
        mov    0x22,%al
L_000dd4:
        .byte 0x0a,0xc0  # forced-kept: gas re-encodes 'or     %al,%al' differently
L_000dd6:
        je L_000e1c
