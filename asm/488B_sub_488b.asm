# sub_488b — mechanical clean (bulk wave); behavior not yet reviewed
# func 488B..488B  len 0001 B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_488b:
L_004a8b:
        .byte 0xb7  # forced-kept: gas re-encodes 'mov    $0x0,%bh' differently
