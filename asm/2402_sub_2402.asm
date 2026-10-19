# sub_2402 — mechanical clean (bulk wave); behavior not yet reviewed
# func 2402..2409  len 0008 B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_2402:
L_002602:
        mov    0x197(%di),%al
L_002606:
        cmp    $0x0,%al
L_002608:
        je L_00261f
