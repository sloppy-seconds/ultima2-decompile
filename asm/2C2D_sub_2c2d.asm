# sub_2c2d — mechanical clean (bulk wave); behavior not yet reviewed
# func 2C2D..2C34  len 0008 B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_2c2d:
L_002e2d:
        mov    0x197(%di),%al
L_002e31:
        cmp    $0x40,%al
L_002e33:
        je L_002e38
