# sub_0ba0 — mechanical clean (bulk wave); behavior not yet reviewed
# func 0BA0..0BA7  len 0008 B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_0ba0:
L_000da0:
        nop
L_000da1:
        mov    0x4a,%al
L_000da4:
        .byte 0x0a,0xc0  # forced-kept: gas re-encodes 'or     %al,%al' differently
L_000da6:
        je L_000dab
