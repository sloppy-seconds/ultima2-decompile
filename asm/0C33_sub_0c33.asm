# sub_0c33 — mechanical clean (bulk wave); behavior not yet reviewed
# func 0C33..0C39  len 0007 B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_0c33:
L_000e33:
        mov    0x26b,%al
L_000e36:
        .byte 0x0a,0xc0  # forced-kept: gas re-encodes 'or     %al,%al' differently
L_000e38:
        je L_000e3e
