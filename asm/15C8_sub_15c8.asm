# sub_15c8 — mechanical clean (bulk wave); behavior not yet reviewed
# func 15C8..15CF  len 0008 B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_15c8:
L_0017c8:
        nop
L_0017c9:
        mov    0x4a,%al
L_0017cc:
        cmp    $0x2,%al
L_0017ce:
        jne L_0017d3
