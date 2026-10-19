# sub_4ad7 — mechanical clean (bulk wave); behavior not yet reviewed
# func 4AD7..4ADF  len 0009 B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_4ad7:
L_004cd7:
        add    $0x10,%bx
L_004cda:
        cmp    $0xa0,%bx
L_004cde:
        jb L_004cb8
