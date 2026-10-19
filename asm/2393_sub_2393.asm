# sub_2393 — mechanical clean (bulk wave); behavior not yet reviewed
# func 2393..2394  len 0002 B  evidence: reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_2393:
L_002593:
        fwait
L_002594:
        .byte 0xe6  # forced-kept: gas re-encodes 'out    %al,$0x90' differently
