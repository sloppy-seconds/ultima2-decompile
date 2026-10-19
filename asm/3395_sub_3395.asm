# sub_3395 — mechanical clean (bulk wave); behavior not yet reviewed
# func 3395..3398  len 0004 B  evidence: reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_3395:
L_003595:
        .byte 0x0a,0xc0  # forced-kept: gas re-encodes 'or     %al,%al' differently
L_003597:
        je L_0035a6
