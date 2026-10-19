# sub_5aed — mechanical clean (bulk wave); behavior not yet reviewed
# func 5AED..5AF8  len 000C B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_5aed:
L_005ced:
        clc
L_005cee:
        mov    0x5,%al
L_005cf1:
        adc    0x3,%al
L_005cf5:
        cmp    $0x40,%al
L_005cf7:
        jb L_005cff
