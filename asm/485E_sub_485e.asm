# sub_485e — mechanical clean (bulk wave); behavior not yet reviewed
# func 485E..4860  len 0003 B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_485e:
L_004a5e:
        mov    $0x0,%bh
L_004a60:
        .byte 0xb3  # forced-kept: gas re-encodes 'mov    $0x0,%bl' differently
