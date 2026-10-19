# sub_5111 — mechanical clean (bulk wave); behavior not yet reviewed
# func 5111..5111  len 0001 B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_5111:
L_005311:
        .byte 0xb7  # forced-kept: gas re-encodes 'mov    $0x0,%bh' differently
