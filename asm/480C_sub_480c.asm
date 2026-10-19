# sub_480c — mechanical clean (bulk wave); behavior not yet reviewed
# func 480C..480C  len 0001 B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_480c:
L_004a0c:
        .byte 0x8a  # forced-kept: gas re-encodes 'mov    0xb6(%di),%al' differently
