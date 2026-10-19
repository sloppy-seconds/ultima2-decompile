# sub_1040 — mechanical clean (bulk wave); behavior not yet reviewed
# func 1040..1047  len 0008 B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_1040:
L_001240:
        mov    0x197(%di),%al
L_001244:
        cmp    $0x40,%al
L_001246:
        jne L_00126d
