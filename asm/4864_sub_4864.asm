# sub_4864 — mechanical clean (bulk wave); behavior not yet reviewed
# func 4864..4864  len 0001 B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_4864:
L_004a64:
        .byte 0x8a  # forced-kept: gas re-encodes 'mov    0xd6(%di),%al' differently
