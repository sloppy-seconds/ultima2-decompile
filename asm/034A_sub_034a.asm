# sub_034a — mechanical clean (bulk wave); behavior not yet reviewed
# func 034A..034A  len 0001 B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_034a:
L_00054a:
        .byte 0xc6  # forced-kept: gas re-encodes 'movb   $0x11,0x2f' differently
