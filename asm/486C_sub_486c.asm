# sub_486c — mechanical clean (bulk wave); behavior not yet reviewed
# func 486C..486C  len 0001 B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_486c:
L_004a6c:
        .byte 0x8b  # forced-kept: gas re-encodes 'mov    %di,%bx' differently
