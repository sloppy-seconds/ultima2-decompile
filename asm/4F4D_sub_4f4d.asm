# sub_4f4d — mechanical clean (bulk wave); behavior not yet reviewed
# func 4F4D..4F51  len 0005 B  evidence: seed+call+reko
# seams: key_int16
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_4f4d:
L_00514d:
        push   %bx
L_00514e:
        mov    $0x1,%ah
L_005150:
key_int16:
        int $0x16    # key_int16 seam
