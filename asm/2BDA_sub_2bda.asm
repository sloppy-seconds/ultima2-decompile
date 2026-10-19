# sub_2bda — mechanical clean (bulk wave); behavior not yet reviewed
# func 2BDA..2BE2  len 0009 B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_2bda:
L_002dda:
        clc
L_002ddb:
        rcr    $1,%al
L_002ddd:
        cmp    0x4c,%al
L_002de1:
        jb L_002de6
