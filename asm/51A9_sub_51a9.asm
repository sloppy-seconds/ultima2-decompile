# sub_51a9 — mechanical clean (bulk wave); behavior not yet reviewed
# func 51A9..51AD  len 0005 B  evidence: seed+reko
# calls: L_0055b5
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_51a9:
L_0053a9:
        .byte 0x8b,0xc7  # forced-kept: gas re-encodes 'mov    %di,%ax' differently
L_0053ab:
        call L_0055b5
