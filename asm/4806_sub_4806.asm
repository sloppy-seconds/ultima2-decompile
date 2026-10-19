# sub_4806 — mechanical clean (bulk wave); behavior not yet reviewed
# func 4806..4808  len 0003 B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_4806:
L_004a06:
        mov    $0x0,%bh
L_004a08:
        .byte 0xb3  # forced-kept: gas re-encodes 'mov    $0x1,%bl' differently
