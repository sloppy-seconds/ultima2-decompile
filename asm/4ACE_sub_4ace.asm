# sub_4ace — mechanical clean (bulk wave); behavior not yet reviewed
# func 4ACE..4AD6  len 0009 B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_4ace:
L_004cce:
        inc    %si
L_004ccf:
        .byte 0x05,0x10,0x00  # forced-kept: gas re-encodes 'add    $0x10,%ax' differently
L_004cd2:
        cmp    $0x140,%ax
L_004cd5:
        jb L_004cbb
