# sub_4ae6 — mechanical clean (bulk wave); behavior not yet reviewed
# func 4AE6..4AEE  len 0009 B  evidence: seed+call+reko
# calls: L_004cfc
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_4ae6:
L_004ce6:
        push   %si
L_004ce7:
        mov    %cs:0x79c0,%si
L_004cec:
        call L_004cfc
