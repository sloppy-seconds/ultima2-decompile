# sub_0951 — mechanical clean (bulk wave); behavior not yet reviewed
# func 0951..0954  len 0004 B  evidence: reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_0951:
L_000b51:
        outsb  %ds:(%si),(%dx)
L_000b52:
        add    0x21(%di),%dh
