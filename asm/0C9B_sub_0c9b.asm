# sub_0c9b — mechanical clean (bulk wave); behavior not yet reviewed
# func 0C9B..0C9B  len 0001 B  evidence: reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_0c9b:
L_000e9b:
        .byte 0xfe  # forced-kept: gas re-encodes '(bad)' differently
