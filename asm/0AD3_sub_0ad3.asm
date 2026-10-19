# sub_0ad3 — mechanical clean (bulk wave); behavior not yet reviewed
# func 0AD3..0ADA  len 0008 B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_0ad3:
L_000cd3:
        mov    0x197(%di),%al
L_000cd7:
        cmp    $0x34,%al
L_000cd9:
        jne L_000ce1
