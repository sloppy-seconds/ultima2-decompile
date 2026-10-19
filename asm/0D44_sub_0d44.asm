# sub_0d44 — mechanical clean (bulk wave); behavior not yet reviewed
# func 0D44..0D4B  len 0008 B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_0d44:
L_000f44:
        mov    0x1b7(%di),%al
L_000f48:
        cmp    $0x8,%al
L_000f4a:
        je L_000f4f
