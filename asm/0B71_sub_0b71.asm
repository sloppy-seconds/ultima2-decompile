# sub_0b71 — mechanical clean (bulk wave); behavior not yet reviewed
# func 0B71..0B78  len 0008 B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_0b71:
L_000d71:
        and    $0x7,%al
L_000d73:
        cmp    0x62,%al
L_000d77:
        jb L_000da0
