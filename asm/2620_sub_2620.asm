# sub_2620 — mechanical clean (bulk wave); behavior not yet reviewed
# func 2620..2625  len 0006 B  evidence: seed+reko
# calls: L_0027ff
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_2620:
L_002820:
        cmp    $0x80,%al
L_002822:
        je L_002804
L_002824:
        jmp L_0027ff
