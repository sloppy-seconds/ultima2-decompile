# sub_47ae — mechanical clean (bulk wave); behavior not yet reviewed
# func 47AE..47B0  len 0003 B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_47ae:
L_0049ae:
        mov    $0x0,%bh
L_0049b0:
        .byte 0xb3  # forced-kept: gas re-encodes 'mov    $0x1,%bl' differently
