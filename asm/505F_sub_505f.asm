# sub_505f — mechanical clean (bulk wave); behavior not yet reviewed
# func 505F..5065  len 0007 B  evidence: seed+call+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_505f:
L_00525f:
        mov    0x46,%al
L_005262:
        cmp    $0x4d,%al
L_005264:
        jne L_00526f
