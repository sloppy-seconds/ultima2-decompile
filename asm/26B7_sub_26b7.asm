# sub_26b7 — mechanical clean (bulk wave); behavior not yet reviewed
# func 26B7..26C2  len 000C B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_26b7:
L_0028b7:
        mov    0x6e,%al
L_0028ba:
        clc
L_0028bb:
        rcr    $1,%al
L_0028bd:
        cmp    0x49,%al
L_0028c1:
        jb L_0028c6
