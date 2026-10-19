# sub_0d64 — mechanical clean (bulk wave); behavior not yet reviewed
# func 0D64..0D6B  len 0008 B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_0d64:
L_000f64:
        mov    0x1b7(%di),%al
L_000f68:
        cmp    $0x8,%al
L_000f6a:
        je L_000f6f
