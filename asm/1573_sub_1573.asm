# sub_1573 — mechanical clean (bulk wave); behavior not yet reviewed
# func 1573..157A  len 0008 B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_1573:
L_001773:
        inc    %di
L_001774:
        mov    %es:(%di),%al
L_001777:
        cmp    $0x0,%al
L_001779:
        je L_001780
