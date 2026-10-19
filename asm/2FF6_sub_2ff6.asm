# sub_2ff6 — mechanical clean (bulk wave); behavior not yet reviewed
# func 2FF6..2FFD  len 0008 B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_2ff6:
L_0031f6:
        nop
L_0031f7:
        mov    0xe2,%al
L_0031fa:
        .byte 0x0a,0xc0  # forced-kept: gas re-encodes 'or     %al,%al' differently
L_0031fc:
        jne L_003238
