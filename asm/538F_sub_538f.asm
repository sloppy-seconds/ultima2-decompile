# sub_538f — mechanical clean (bulk wave); behavior not yet reviewed
# func 538F..539F  len 0011 B  evidence: call+reko
# calls: L_0055a0
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_538f:
L_00558f:
        movb   $0x17,0x2f
L_005594:
        call L_0055a0
L_005597:
        movb   $0x18,0x2f
L_00559c:
        call L_0055a0
L_00559f:
        ret
