# sub_02f7 — mechanical clean (bulk wave); behavior not yet reviewed
# func 02F7..02F7  len 0001 B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_02f7:
L_0004f7:
        .byte 0xc6  # forced-kept: gas re-encodes 'movb   $0xd,0x2f' differently
