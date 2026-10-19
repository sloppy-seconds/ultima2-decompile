# sub_3045 — mechanical clean (bulk wave); behavior not yet reviewed
# func 3045..3047  len 0003 B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_3045:
L_003245:
        mov    $0x0,%al
L_003247:
        .byte 0xb4  # forced-kept: gas re-encodes 'mov    $0x0,%ah' differently
