# sub_0c54 — mechanical clean (bulk wave); behavior not yet reviewed
# func 0C54..0C5A  len 0007 B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_0c54:
L_000e54:
        mov    0x26a,%al
L_000e57:
        .byte 0x0a,0xc0  # forced-kept: gas re-encodes 'or     %al,%al' differently
L_000e59:
        je L_000e5f
