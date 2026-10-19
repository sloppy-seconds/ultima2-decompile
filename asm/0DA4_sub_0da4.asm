# sub_0da4 — mechanical clean (bulk wave); behavior not yet reviewed
# func 0DA4..0DAB  len 0008 B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_0da4:
L_000fa4:
        mov    0x1b7(%di),%al
L_000fa8:
        cmp    $0x0,%al
L_000faa:
        je L_000faf
