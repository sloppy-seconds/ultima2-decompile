# sub_15d6 — mechanical clean (bulk wave); behavior not yet reviewed
# func 15D6..15DD  len 0008 B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_15d6:
L_0017d6:
        nop
L_0017d7:
        mov    0x4a,%al
L_0017da:
        cmp    $0x2,%al
L_0017dc:
        jne L_0017e1
