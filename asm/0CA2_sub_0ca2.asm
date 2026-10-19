# sub_0ca2 — mechanical clean (bulk wave); behavior not yet reviewed
# func 0CA2..0CA9  len 0008 B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_0ca2:
L_000ea2:
        mov    0x197(%di),%al
L_000ea6:
        .byte 0x0a,0xc0  # forced-kept: gas re-encodes 'or     %al,%al' differently
L_000ea8:
        je L_000eb0
