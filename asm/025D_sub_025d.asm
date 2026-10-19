# sub_025d — mechanical clean (bulk wave); behavior not yet reviewed
# func 025D..025D  len 0001 B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_025d:
L_00045d:
        .byte 0xc6  # forced-kept: gas re-encodes 'movb   $0x3,0x2f' differently
