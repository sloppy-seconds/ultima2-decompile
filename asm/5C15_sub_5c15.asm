# sub_5c15 — mechanical clean (bulk wave); behavior not yet reviewed
# func 5C15..5C1B  len 0007 B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_5c15:
L_005e15:
        cmpb   $0xff,0x54e
L_005e1a:
        jne L_005e25
