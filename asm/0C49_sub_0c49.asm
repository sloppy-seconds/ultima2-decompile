# sub_0c49 — mechanical clean (bulk wave); behavior not yet reviewed
# func 0C49..0C4F  len 0007 B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_0c49:
L_000e49:
        mov    0x26d,%al
L_000e4c:
        .byte 0x0a,0xc0  # forced-kept: gas re-encodes 'or     %al,%al' differently
L_000e4e:
        je L_000e54
