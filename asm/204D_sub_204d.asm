# sub_204d — mechanical clean (bulk wave); behavior not yet reviewed
# func 204D..2051  len 0005 B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_204d:
L_00224d:
        .byte 0x8b,0xc7  # forced-kept: gas re-encodes 'mov    %di,%ax' differently
L_00224f:
        cmp    $0x0,%al
L_002251:
        ret
