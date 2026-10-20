# sub_4887 — mechanical clean (bulk wave); behavior not yet reviewed
# func 4887..488A  len 0004 B  evidence: reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_4887:
L_004a87:
        push   %si
L_004a88:
        pop    %es
L_004a89:
        .byte 0x2d,0x00  # forced-kept: gas re-encodes 'sub    $0xb700,%ax' differently
