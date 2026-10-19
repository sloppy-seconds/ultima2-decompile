# sub_353a — mechanical clean (bulk wave); behavior not yet reviewed
# func 353A..353C  len 0003 B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_353a:
L_00373a:
        mov    $0x0,%bh
L_00373c:
        .byte 0x8a  # forced-kept: gas re-encodes 'mov    0x49,%bl' differently
