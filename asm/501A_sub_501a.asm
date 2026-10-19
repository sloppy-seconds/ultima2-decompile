# sub_501a — mechanical clean (bulk wave); behavior not yet reviewed
# func 501A..5024  len 000B B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_501a:
L_00521a:
        incb   0x2f
L_00521e:
        cmpb   $0x18,0x2f
L_005223:
        jne L_005257
