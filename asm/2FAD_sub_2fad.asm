# sub_2fad — mechanical clean (bulk wave); behavior not yet reviewed
# func 2FAD..2FB3  len 0007 B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_2fad:
L_0031ad:
        mov    0x14,%al
L_0031b0:
        cmp    $0x22,%al
L_0031b2:
        je L_0031d6
