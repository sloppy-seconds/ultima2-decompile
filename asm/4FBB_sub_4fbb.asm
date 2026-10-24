# sub_4fbb — arrow-table scan, initialiser: bx = 6, i.e. the four pairs at CS:0x4F09..0x4F10
#           are walked BACKWARDS (6, 4, 2, 0). Order is irrelevant to the result but it is what
#           the bytes do, and it is what makes the table look like a stack if read forwards.
# func 4FBB..4FBD  len 0003 B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_4fbb:
L_0051bb:
        mov    $0x6,%bx
