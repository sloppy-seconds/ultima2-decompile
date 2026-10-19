# sub_17f0 — mechanical clean (bulk wave); behavior not yet reviewed
# func 17F0..17F1  len 0002 B  evidence: reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_17f0:
L_0019f0:
        .byte 0x41  # forced-kept: gas re-encodes 'inc    %cx' differently
L_0019f1:
        .byte 0xf2  # forced-kept: gas re-encodes 'bnd call 0x51df' differently
