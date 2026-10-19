# sub_0c02 — mechanical clean (bulk wave); behavior not yet reviewed
# func 0C02..0C08  len 0007 B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_0c02:
L_000e02:
        mov    0x4a,%al
L_000e05:
        .byte 0x0a,0xc0  # forced-kept: gas re-encodes 'or     %al,%al' differently
L_000e07:
        je L_000e1c
