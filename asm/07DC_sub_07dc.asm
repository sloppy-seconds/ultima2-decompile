# sub_07dc — mechanical clean (bulk wave); behavior not yet reviewed
# func 07DC..07DD  len 0002 B  evidence: reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_07dc:
L_0009dc:
        outsw  %ds:(%si),(%dx)
L_0009dd:
        inc    %di
