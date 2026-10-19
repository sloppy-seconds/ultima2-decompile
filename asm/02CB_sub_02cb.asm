# sub_02cb — mechanical clean (bulk wave); behavior not yet reviewed
# func 02CB..02CB  len 0001 B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_02cb:
L_0004cb:
        .byte 0xc6  # forced-kept: gas re-encodes 'movb   $0x17,0x2f' differently
