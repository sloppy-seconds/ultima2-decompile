# sub_4307 — mechanical clean (bulk wave); behavior not yet reviewed
# func 4307..4308  len 0002 B  evidence: reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_4307:
L_004507:
        pop    %cx
L_004508:
        .byte 0xe0  # forced-kept: stop-trunc loopne 0x44aa
