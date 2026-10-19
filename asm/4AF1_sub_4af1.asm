# sub_4af1 — mechanical clean (bulk wave); behavior not yet reviewed
# func 4AF1..4AF9  len 0009 B  evidence: seed+call+reko
# calls: L_004cfc
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_4af1:
L_004cf1:
        push   %si
L_004cf2:
        mov    %cs:0x79ee,%si
L_004cf7:
        call L_004cfc
