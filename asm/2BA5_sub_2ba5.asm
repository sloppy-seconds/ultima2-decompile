# sub_2ba5 — mechanical clean (bulk wave); behavior not yet reviewed
# func 2BA5..2BAC  len 0008 B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_2ba5:
L_002da5:
        nop
L_002da6:
        mov    0x26c,%al
L_002da9:
        .byte 0x0a,0xc0  # forced-kept: gas re-encodes 'or     %al,%al' differently
L_002dab:
        je L_002dbe
