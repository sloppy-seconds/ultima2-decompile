# sub_475c — mechanical clean (bulk wave); behavior not yet reviewed
# func 475C..4762  len 0007 B  evidence: reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_475c:
L_00495c:
        test   %si,0x0(%bp)
L_00495f:
        .byte 0x0a,0xc0  # forced-kept: gas re-encodes 'or     %al,%al' differently
L_004961:
        je L_00498b
