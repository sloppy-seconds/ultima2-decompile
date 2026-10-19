# sub_4755 — mechanical clean (bulk wave); behavior not yet reviewed
# func 4755..4757  len 0003 B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_4755:
L_004955:
        mov    $0x0,%bh
L_004957:
        .byte 0xb3  # forced-kept: gas re-encodes 'mov    $0x1,%bl' differently
