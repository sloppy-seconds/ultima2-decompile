# sub_4207 — mechanical clean (bulk wave); behavior not yet reviewed
# func 4207..4208  len 0002 B  evidence: reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_4207:
L_004407:
        .byte 0x9d  # forced-kept: gas re-encodes 'popf' differently
L_004408:
        .byte 0xfe  # forced-kept: gas re-encodes '(bad)' differently
