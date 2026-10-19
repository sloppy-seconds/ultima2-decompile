# sub_5ab1 — mechanical clean (bulk wave); behavior not yet reviewed
# func 5AB1..5AB7  len 0007 B  evidence: seed+call+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_5ab1:
L_005cb1:
        cmpb   $0xff,0x12
L_005cb6:
        jne L_005cbb
