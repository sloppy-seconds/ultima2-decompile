# sub_094f — mechanical clean (bulk wave); behavior not yet reviewed
# func 094F..0950  len 0002 B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_094f:
L_000b4f:
        .byte 0x3a,0x06  # forced-kept: gas re-encodes 'cmp    0x26e,%al' differently
