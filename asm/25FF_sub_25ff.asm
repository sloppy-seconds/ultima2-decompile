# sub_25ff — mechanical clean (bulk wave); behavior not yet reviewed
# func 25FF..2603  len 0005 B  evidence: seed+call+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_25ff:
L_0027ff:
        mov    $0xff,%al
L_002801:
        cmp    $0x0,%al
L_002803:
        ret
